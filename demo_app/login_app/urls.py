"""
URL patterns for the login application.
"""
from django.urls import path
from . import views

urlpatterns = [
    # Login page (GET)
    path('login/', views.login_page, name='login_page'),
    
    # Login submission (POST)
    path('login/submit/', views.login_submit, name='login_submit'),
    
    # Health check endpoint
    path('health/', views.health_check, name='health_check'),
    
    # Database status check
    path('db-status/', views.database_status, name='database_status'),
    
    # Root redirect to login
    path('', views.login_page, name='root'),
]
