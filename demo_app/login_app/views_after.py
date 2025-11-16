"""
AFTER version: Views with Django standard error handling (HTTP 500)

This version demonstrates the correct error handling approach where
database errors are allowed to propagate, resulting in proper HTTP 500
error responses that monitoring tools can detect.

This is the "Fixed" scenario where:
- Database errors result in HTTP 500 status codes
- Monitoring tools correctly identify the error
- Proper alerting and incident response can occur
"""

from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.auth import authenticate
from .db_utils import DatabaseConnection
import psycopg2


def index_view(request):
    """Home page view"""
    return render(request, 'login_app/index.html')


def login_view(request):
    """
    Login view with Django standard error handling (AFTER version)
    
    SOLUTION: This view does NOT catch OperationalError.
    Exceptions propagate to Django's standard error handler, which returns HTTP 500.
    """
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        # No try-except for database errors!
        # Let Django's standard error handling deal with it
        
        # Use custom database connection class
        conn = DatabaseConnection.get_connection()  # May raise OperationalError
        cursor = conn.cursor()
        
        # Query user from database
        cursor.execute(
            "SELECT id, username, password FROM auth_user WHERE username = %s",
            [username]
        )
        user = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if user:
            # In a real application, you would verify the password hash here
            # For demo purposes, we just check if user exists
            return HttpResponse(
                "<h1>Login Success</h1><p>Welcome back!</p>",
                status=200
            )
        else:
            return HttpResponse(
                "<h1>Login Failed</h1><p>Invalid username or password</p>",
                status=401
            )
            
    return render(request, 'login_app/login.html')


def custom_500_view(request):
    """
    Custom 500 error page view
    
    In AFTER version, this is typically not accessed via redirect.
    Django's standard error handler will render templates/500.html directly.
    This view exists for compatibility.
    """
    return render(request, 'login_app/500.html', status=500)  # Returns HTTP 500
