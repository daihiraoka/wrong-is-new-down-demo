"""
Custom Database Access Class

This class demonstrates how applications may implement custom database
connection logic that bypasses Django's standard ORM connection management.

IMPORTANT: The DB_NAME can be different from Django's settings.py DATABASE configuration.
This is the key to reproducing the "Wrong is the new Down" scenario.
"""

import psycopg2
import os


class DatabaseConnection:
    """
    Custom database connection class that manages its own database connections.
    
    This class intentionally does NOT use Django's settings.py DATABASES configuration.
    Instead, it uses its own DB_NAME which can be modified to simulate database errors.
    """
    
    # Class variable: Database name used by this custom connection class
    # This can be different from Django's settings.py configuration
    DB_NAME = 'demo_app'  # Default: correct database name
    
    # Other connection parameters
    DB_USER = os.getenv('DB_USER', 'postgres')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = os.getenv('DB_PORT', '5432')
    
    @classmethod
    def get_connection(cls):
        """
        Create and return a new database connection.
        
        This method connects to the database specified by cls.DB_NAME,
        which is independent of Django's settings.py configuration.
        
        Returns:
            psycopg2.connection: Database connection object
            
        Raises:
            psycopg2.OperationalError: If connection fails (e.g., database does not exist)
        """
        return psycopg2.connect(
            host=cls.DB_HOST,
            port=cls.DB_PORT,
            database=cls.DB_NAME,  # This is the key: can be different from Django's config
            user=cls.DB_USER,
            password=cls.DB_PASSWORD
        )
    
    @classmethod
    def set_database_name(cls, db_name):
        """
        Change the database name used by this connection class.
        
        This method is used by the scenario switching scripts to simulate
        database configuration errors.
        
        Args:
            db_name (str): New database name to use
        """
        cls.DB_NAME = db_name
