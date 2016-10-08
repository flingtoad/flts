DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': '<%= $conf->{"project"} %>',
        'USER': '<%= $conf->{"project"} %>',
        'PASSWORD': '<%= $conf->{"password"} %>',
        'HOST': 'localhost',   # Or an IP Address that your DB is hosted on
        'PORT': '',
    }
}
