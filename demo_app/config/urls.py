"""
URL configuration for Wrong is the new Down demo project.
"""
from django.contrib import admin
from django.urls import path
from login_app import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.index_view, name='index'),
    path('login/', views.login_view, name='login'),
    path('500.html', views.custom_500_view, name='custom_500'),
]
