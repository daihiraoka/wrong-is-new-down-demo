"""
Custom error handler middleware.

This middleware demonstrates the "Wrong is the new Down" phenomenon
by returning HTTP 302 instead of HTTP 500 for server errors.
"""

import logging
from django.http import HttpResponseRedirect, HttpResponseServerError
from django.conf import settings
from django.urls import reverse

logger = logging.getLogger(__name__)


class CustomErrorHandlerMiddleware:
    """
    Custom error handler middleware.
    
    When USE_CUSTOM_ERROR_HANDLER=True in settings:
    - Catches exceptions during request processing
    - Returns HTTP 302 (redirect) instead of HTTP 500
    - This causes Instana to interpret the error as "normal"
    
    When USE_CUSTOM_ERROR_HANDLER=False:
    - This middleware is bypassed
    - Django returns standard HTTP 500 error
    - Instana correctly detects the error
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        self.enabled = getattr(settings, 'USE_CUSTOM_ERROR_HANDLER', False)
        
        if self.enabled:
            logger.warning("Custom Error Handler is ENABLED - HTTP 302 will be returned on errors")
        else:
            logger.info("Custom Error Handler is DISABLED - Standard HTTP 500 will be returned on errors")
    
    def __call__(self, request):
        # Process the request
        response = self.get_response(request)
        return response
    
    def process_exception(self, request, exception):
        """
        Process exceptions that occur during request handling.
        
        This is the key method that demonstrates the "Wrong is the new Down" issue.
        """
        
        # Only intercept if custom error handler is enabled
        if not self.enabled:
            return None  # Let Django handle the error normally
        
        # Log the error
        logger.error(f"Exception caught by CustomErrorHandlerMiddleware: {str(exception)}")
        logger.error(f"Exception type: {type(exception).__name__}")
        logger.error(f"Request path: {request.path}")
        logger.error(f"Request method: {request.method}")
        
        # THIS IS THE PROBLEM!
        # Instead of returning HTTP 500 (which Instana would detect as an error),
        # we return HTTP 302 (which Instana interprets as a "normal" redirect)
        
        # Return HTTP 302 redirect to the login page
        # This is the "wrong" behavior that creates the "Wrong is the new Down" phenomenon
        redirect_url = reverse('login_page')
        logger.warning(f"Returning HTTP 302 redirect to {redirect_url} (This is the problem!)")
        
        return HttpResponseRedirect(redirect_url)
    
    @staticmethod
    def return_server_error():
        """
        Return a proper HTTP 500 error.
        
        This is the "correct" behavior that should be used.
        """
        return HttpResponseServerError("Internal Server Error")


# For debugging: Print middleware status on startup
if __name__ != '__main__':
    enabled = getattr(settings, 'USE_CUSTOM_ERROR_HANDLER', False)
    if enabled:
        print("\n" + "="*60)
        print("⚠️  WARNING: Custom Error Handler is ENABLED")
        print("="*60)
        print("This will cause HTTP 302 to be returned on errors,")
        print("demonstrating the 'Wrong is the new Down' phenomenon.")
        print("="*60 + "\n")
    else:
        print("\n" + "="*60)
        print("✅ Custom Error Handler is DISABLED")
        print("="*60)
        print("Django will return standard HTTP 500 on errors.")
        print("="*60 + "\n")
