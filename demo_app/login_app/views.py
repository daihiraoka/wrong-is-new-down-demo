"""
Views for the login application.

This module demonstrates the "Wrong is the new Down" phenomenon.
"""

import logging
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import connection

logger = logging.getLogger(__name__)


def login_page(request):
    """
    Display the login page.
    
    This is a simple GET endpoint that renders the login template.
    """
    return render(request, 'login.html')


@csrf_exempt
def login_submit(request):
    """
    Handle login form submission.
    
    This endpoint intentionally triggers a database error to demonstrate
    the "Wrong is the new Down" phenomenon.
    
    Expected behavior:
    - When USE_CUSTOM_ERROR_HANDLER=True: Returns HTTP 302 (redirect)
    - When USE_CUSTOM_ERROR_HANDLER=False: Returns HTTP 500 (server error)
    
    The database error is triggered by attempting to connect to a
    non-existent database, simulating a configuration error.
    """
    
    if request.method != 'POST':
        return JsonResponse({
            'status': 'error',
            'message': 'Only POST method is allowed'
        }, status=405)
    
    # Get form data
    username = request.POST.get('username', '')
    password = request.POST.get('password', '')
    
    logger.info(f"Login attempt for username: {username}")
    
    try:
        # Intentionally trigger a database error
        # This simulates a database connection problem
        with connection.cursor() as cursor:
            # This query will fail if the database configuration is "broken"
            cursor.execute("SELECT 1 FROM auth_user WHERE username = %s", [username])
            result = cursor.fetchone()
        
        # If we get here, the database connection is working
        logger.info(f"Login successful for username: {username}")
        return JsonResponse({
            'status': 'success',
            'message': 'Login successful',
            'username': username
        }, status=200)
    
    except Exception as e:
        # This is where the "Wrong is the new Down" phenomenon occurs
        logger.error(f"Database error during login: {str(e)}")
        
        # The CustomErrorHandlerMiddleware will intercept this exception
        # and return HTTP 302 if USE_CUSTOM_ERROR_HANDLER=True
        # Otherwise, Django will return HTTP 500
        
        raise  # Re-raise the exception to trigger error handling


def health_check(request):
    """
    Health check endpoint.
    
    Returns 200 OK if the application is running.
    This endpoint is useful for load balancers and monitoring tools.
    """
    return JsonResponse({
        'status': 'healthy',
        'service': 'wrong-is-new-down-demo'
    }, status=200)


def database_status(request):
    """
    Database connection status check.
    
    Returns 200 OK if the database is accessible.
    Returns 500 Internal Server Error if the database is not accessible.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
        
        return JsonResponse({
            'status': 'connected',
            'database': 'accessible'
        }, status=200)
    
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        
        return JsonResponse({
            'status': 'error',
            'message': 'Database connection failed',
            'error': str(e)
        }, status=500)
