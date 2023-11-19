import unittest
import subprocess

# Script Path (relative to the tests directory)
script_path = '../install/install.sh'


class TestInstallScript(unittest.TestCase):
    def test_install(self):
        # Run the install script silently as a service
        subprocess.run(['sudo', 'bash', script_path, '-s', '-i'], check=True)

        # Check if the log_simulator directory exists
        result = subprocess.run(['ls', '/opt'], capture_output=True, text=True)
        self.assertIn('log_simulator', result.stdout)

        # Check if the log_simulator.py script is executable
        result = subprocess.run(['ls', '-l', '/opt/log_simulator/log_simulator.py'], capture_output=True, text=True)
        self.assertIn('rwxr-xr-x', result.stdout)

        # Check if the log_simulator.service file exists
        result = subprocess.run(['ls', '/etc/systemd/system'], capture_output=True, text=True)
        self.assertIn('log_simulator.service', result.stdout)

        # Check if the log_simulator service is enabled and running
        result = subprocess.run(['systemctl', 'is-enabled', 'log_simulator'], capture_output=True, text=True)
        self.assertIn('enabled', result.stdout)

        result = subprocess.run(['systemctl', 'is-active', 'log_simulator'], capture_output=True, text=True)
        self.assertIn('active', result.stdout)

    def test_uninstall(self):
        # Run the uninstall script with default options
        subprocess.run(['sudo', 'bash', script_path, '-u'], check=True)

        # Check if the log_simulator directory does not exist
        result = subprocess.run(['ls', '/opt'], capture_output=True, text=True)
        self.assertNotIn('log_simulator', result.stdout)

        # Check if the log_simulator.service file does not exist
        result = subprocess.run(['ls', '/etc/systemd/system'], capture_output=True, text=True)
        self.assertNotIn('log_simulator.service', result.stdout)

        # Check if the log_simulator service is disabled and not running
        result = subprocess.run(['systemctl', 'is-enabled', 'log_simulator'], capture_output=True, text=True)
        self.assertIn('disabled', result.stdout)

        result = subprocess.run(['systemctl', 'is-active', 'log_simulator'], capture_output=True, text=True)
        self.assertNotIn('active', result.stdout)

if __name__ == '__main__':
    unittest.main()