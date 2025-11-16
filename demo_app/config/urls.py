"""
URL configuration for Wrong is the new Down demo project.
"""
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('login_app.urls')),
]
