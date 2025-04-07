def run_console_mode(mpu, config):
    """Run in console mode showing sensor data"""
    global running
    
    # Prepare for non-blocking key input
    import tty
    import termios
    import select
    import sys
    
    # Save terminal settings
    old_settings = termios.tcgetattr(sys.stdin)
    try:
        # Set terminal to raw mode
        tty.setraw(sys.stdin.fileno())
        
        while running:
            # Get sensor data
            data = sensor_data
            
            # Get direction arrows
            ax = data["acceleration"]["x"]
            ay = data["acceleration"]["y"]
            az = data["acceleration"]["z"]
            
            gx = data["gyro"]["x"]
            gy = data["gyro"]["y"]
            gz = data["gyro"]["z"]
            
            temp = data["temperature"]
            temp_f = (temp * 9/5) + 32
            
            # Direction arrows
            acc_x_arrow = get_horizontal_arrow(ax)
            acc_y_arrow = get_vertical_arrow(ay)
            acc_z_arrow = get_horizontal_arrow(az)
            
            gyro_x_arrow = get_vertical_arrow(gx)
            gyro_y_arrow = get_vertical_arrow(gy)
            gyro_z_arrow = get_horizontal_arrow(gz)
            
            overall_direction = get_direction_arrow(ax, ay)
            
            # Clear screen
            os.system('clear')
            
            # Display header
            print("╔══════════════════════════════════════════════════════╗")
            print("║               MPU6050 MONITOR v1.0.3                 ║")
            print("╠══════════════════════════════════════════════════════╣")
            
            # One line status display
            print(f"║ Acc(m/s²) X:{ax:7.2f}{acc_x_arrow} Y:{ay:7.2f}{acc_y_arrow} Z:{az:7.2f}{acc_z_arrow} | Gyro X:{gx:6.2f}{gyro_x_arrow} Y:{gy:6.2f}{gyro_y_arrow} Z:{gz:6.2f}{gyro_z_arrow} | T:{temp:5.1f}°C/{temp_f:5.1f}°F ║")
            
            # Additional info
            print("╠══════════════════════════════════════════════════════╣")
            print(f"║ Direction: {overall_direction}                             ║")
            print(f"║ Web Interface: http://localhost:5000             ║")
            print(f"║ API: http://localhost:5000/api/v1/data           ║")
            print("╠══════════════════════════════════════════════════════╣")
            print("║ [c] Calibrate  [q] Quit              ║")
            print("╚══════════════════════════════════════════════════════╝")
            
            # Check for keypresses with timeout
            rlist, _, _ = select.select([sys.stdin], [], [], 0.1)
            if rlist:
                key = sys.stdin.read(1)
                if key.lower() == 'q':
                    running = False
                    break
                elif key.lower() == 'c':
                    # Reset terminal settings before calibrating
                    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
                    calibrate_sensor(mpu)
                    # Set terminal back to raw mode
                    tty.setraw(sys.stdin.fileno())
            
            time.sleep(0.2)  # Slower refresh rate to reduce flicker
            
    finally:
        # Restore terminal settings
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
        print("\nExiting...")
