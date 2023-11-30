"""
This script generates logs in either syslog or CEF format, with a specified logging facility, number of events, event logging rate, logging level, and total running time. The generated logs contain random data for various fields, such as device vendor, product, and version, as well as authentication-related fields like user, outcome, and reason.
This script can be run on any Linux system with Python 3.10 or later installed. It requires the following Python packages:
    - logging
    - time
    - argparse
    - sys
    - random
    - configparser
    - cefevent

It can be installed as a systemd service by running the following commands:
    /install/install.sh -i

Usage:
    python log_simulator.py [-c CONFIG] [-f FORMAT] [-F FACILITY] [-l LEVEL] [-e EVENTS PER SECOND] [-t RUNTIME]

Options:
    -c, --config CONFIG                         Path to a configuration file.
    -f, --format FORMAT                         The logging format. Can be either 'syslog' or 'cef'. Default is 'syslog'.
    -F, --facility FACILITY                     The logging facility. Can be one of 'auth', 'authpriv', 'cron', 'daemon', 'ftp', 'kern', 'lpr', 'mail', 'news', 'syslog', 'user', 'uucp', 'local0', 'local1', 'local2', 'local3', 'local4', 'local5', 'local6', 'local7'. Default is 'syslog'.
    -l, --level LEVEL                           The logging level. Can be one of 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'. Default is 'INFO'.
    -e, --events_per_second EVENTS PER SECOND   The total number of events to log. Default is 1.
    -r, --runtime RUNTIME                       The total running time in seconds. If set to 0, the script will run indefinitely. Default is 0.
    
Examples:
    Generate 50 syslog events per second, to the local0.WARNING facility/level until the script is ended:
        python log_simulator.py --format syslog --facility local0 --WARNING --events 50

        <34>Oct 11 22:14:15 myhost myprogram[12345]: User 'admin' logged in

    Generate CEF events with a logging rate of 10 events per second and a total running time of 300 seconds:
        python log_simulator.py -f cef -e 10 -r 300
"""

import logging
import logging.handlers
import time
import argparse
import sys
import random
import configparser
from cefevent.event import CEFEvent

script_name = "log_simulator"

valid_facilities = ["auth", "authpriv", "cron", "daemon", "ftp", "kern", "lpr", "mail", "news", "syslog", "user", "uucp", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"]
valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]

def check_facility(facility):
    updated_valid_facilities = valid_facilities + ["console"]
    return facility in updated_valid_facilities


def parse_arguments(args=None):
    parser = argparse.ArgumentParser(description="Generate logs in either syslog or CEF format.")
    parser.add_argument("-c", "--config", type=str, help="Path to a configuration file.")
    parser.add_argument("-f", "--format", type=str, choices=["syslog", "cef"], default="syslog", help="The logging format. Default is 'syslog'.")
    parser.add_argument("-F", "--facility", type=str, choices=valid_facilities, default="syslog", help="The logging facility. Default is 'syslog'.")
    parser.add_argument("-l", "--level", type=str, choices=valid_levels, default="INFO", help="The minimum logging level that will be processed. Default is 'INFO'.")
    parser.add_argument("-e", "--events_per_second", type=int, default=1, help="Number of events to generate per second")
    parser.add_argument("-r", "--runtime", type=int, default=0, help="Total running time in seconds")    
    args = parser.parse_args(args)

    if args.config:
        config = configparser.ConfigParser()
        config.read(args.config)

        args.format = config.get('DEFAULT', 'format', fallback=args.format)
        args.facility = config.get('DEFAULT', 'facility', fallback=args.facility)
        args.level = config.get('DEFAULT', 'level', fallback=args.level)
        args.events_per_second = config.getint('DEFAULT', 'events_per_second', fallback=args.events_per_second)
        args.runtime = config.getint('DEFAULT', 'runtime', fallback=args.runtime)

    if not check_facility(args.facility):
        if args.facility == 'authpriv' and check_facility('security'):
            args.facility = 'security'
        else:
            print(f"Error: The facility '{args.facility}' is not supported on this system.")
            sys.exit(1)

    # Print all arguments
    print("Arguments:")
    for arg in vars(args):
        print(f"{arg}: {getattr(args, arg)}")

    # Check the types of config inputs
    if not isinstance(args.events_per_second, int):
        print("Error: 'events_per_second' in the config file must be an integer.")
        sys.exit(1)

    if not isinstance(args.runtime, int):
        print("Error: 'runtime' in the config file must be an integer.")
        sys.exit(1)

    if args.events_per_second < 0:
        print("Error: Number of events must be greater than or equal to 0.")
        sys.exit(1)

    if args.level == "DEBUG" and args.runtime == 0:
        print("Error: Debug logging requires a finite runtime.")
        sys.exit(1)

    return args


def configure_logger(level, output):
    # Check if level is a valid logging level
    log_level = getattr(logging, level.upper(), None)
    if log_level is None:
        raise ValueError(f"Invalid logging level '{level}'")
    
    formatter = logging.Formatter('%(asctime)s %(name)s %(levelname)s %(message)s')

    # Check if output is a valid syslog facility or 'console'
    if output == 'console':
        handler = logging.StreamHandler()
    else:
        if not check_facility(output):
            raise ValueError(f"Invalid syslog facility '{output}'")
        handler = logging.handlers.SysLogHandler(address='/dev/log', facility=output)

    handler.setLevel(log_level)
    handler.setFormatter(formatter)

    logger = logging.getLogger(script_name)

    # Set the minimum logging level for the logger
    logger.setLevel(log_level)
    logger.addHandler(handler)

    return logger


def generate_random_log_data():

    # Map each combination of auth result and auth event to a unique number
    device_event_class_id_map = {
        ('success', 'login'): 1,
        ('success', 'logout'): 2,
        ('success', 'password_change'): 3,
        ('success', 'account_creation'): 4,
        ('failure', 'login'): 5,
        ('failure', 'logout'): 6,
        ('failure', 'password_change'): 7,
        ('failure', 'account_creation'): 8,
        ('failure', 'invalid_credentials'): 9,
        ('failure', 'expired_password'): 10, 
        ('failure', 'account_locked'): 11
    }
    
    response_map = {
        'success': 'allow',
        'failure': 'deny', 
    }

    reasons = ['unknown', 'expired_password', 'invalid_credentials']
    responses = ['success', 'failure']
    auth_events = ['login', 'logout', 'password_change', 'account_creation']
    users = ['alice', 'bob', 'charlie']

    response = random.choice(responses)
    auth_event = random.choice(auth_events)
    decision = response_map[response]
    reason = random.choice(reasons) if response == 'failure' else None
    user = random.choice(users)

    log_data = {
        'deviceVendor': 'Contoso',
        'deviceProduct': 'Logging Simulator',
        'deviceVersion': '1.0',
        'signatureId': device_event_class_id_map[(response, auth_event)],
        'name': auth_event,
        'severity': str(random.randint(1, 10)),
        'extension': {
            'src': f'192.168.0.{random.randint(1, 255)}',
            'dst': f'192.168.0.{random.randint(1, 255)}',
            'spt': str(random.randint(1024, 65535)),
            'dpt': 22,
            'response': response,
            'user': user,
            'outcome': response,
            'reason': reason,
            'cs1': 'password',
            'deviceProcessName': 'ssh',
            'authDecision': decision,
            'act': auth_event,
            'suser': random.choice(['user', 'admin', 'service_account'])
        }
    }
    return log_data


def format_cef_message(log_data):
    cef_formatted_message = CEFEvent()

    extensions = ' '.join(f'{k}={v}' for k, v in log_data['extension'].items())

    cef_formatted_message.set_field('deviceVendor', log_data['deviceVendor'])
    cef_formatted_message.set_field('deviceProduct', log_data['deviceProduct'])
    cef_formatted_message.set_field('deviceVersion', log_data['deviceVersion'])
    cef_formatted_message.set_field('signatureId', str(log_data['signatureId']))
    cef_formatted_message.set_field('name', log_data['name'])
    cef_formatted_message.set_field('severity', log_data['severity'])
    
    # split the extension into key value pairs and add them to the cef event
    for extension in extensions.split():
        key, value = extension.split('=')
        cef_formatted_message.set_field(key, value)

    return cef_formatted_message


def format_syslog_message(log_data):
    syslog_formatted_message = f"{log_data['deviceVendor']}: User='{log_data['extension']['user']}' Action='{log_data['name']}' response='{log_data['extension']['response']}'"
    return syslog_formatted_message


def generate_log_message(format):   
    if format == 'syslog':
        return format_syslog_message(generate_random_log_data())
    elif format == 'cef':
        return format_cef_message(generate_random_log_data())
    else:
        raise ValueError(f"Invalid format value '{format}'. Format must be either 'syslog' or 'cef'.")


def generate_logs(logger, format, facility, level, events_per_second, runtime):
    # Validate arguments
    if not isinstance(events_per_second, (int, float)) or events_per_second <= 0:
        raise ValueError("events_per_second must be 0 or a positive number")
    
    if level.upper() not in ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]:
        raise ValueError("level must be one of 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'")
    
    if not isinstance(runtime, int) or runtime < 0:
        raise ValueError("runtime must be a non-negative integer")
    
    if facility not in ['console'] + valid_facilities:
        raise ValueError("facility must be 'console' or a valid syslog facility")
    
    level_number = getattr(logging, level.upper(), None)
    if level_number is None:
        raise ValueError(f"Invalid logging level '{level}'")
    
    start_time = time.time()

    while True:
        # Check if runtime has been exceeded
        if runtime > 0 and time.time() - start_time >= runtime:
            break

        log_start_time = time.time()

        for i in range(events_per_second):
            try:
                log_message = generate_log_message(format)
                logger.log(level_number, log_message)
            except ValueError as e:
                logging.error(str(e))
                print(str(e))
                return

        elapsed_time = time.time() - log_start_time
        sleep_time = max(0, 1/events_per_second - elapsed_time)
        time.sleep(sleep_time)


def main():
    args = parse_arguments()
    logger = configure_logger(args.level, args.facility, args.format)
    generate_logs(logger, args.format, args.facility, args.level, args.events_per_second, args.runtime)


if __name__ == "__main__":
    main()


