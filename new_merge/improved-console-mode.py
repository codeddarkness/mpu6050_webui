def run_console_mode(mpu, config):
    """Run in console mode showing sensor data"""
    global running
    
    # Import here to avoid potential circular import
    import select
    import sys
    import termios
    import tty
    
    # Save original terminal settings
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
            print("╔════════════════════════════════════════════════════════════╗")
            print("║               MPU6050 MONITOR v1.0.4                       ║")
            print("╠════════════════════════════════════════════════════════════╣")
            
            # One line status display as requested
            print(f"║ Accel(m/s²) X: {ax:6.2f}{acc_x_arrow} Y: {ay:6.2f}{acc_y_arrow} Z: {az:6.2f}{acc_z_arrow} | ", end='')
            print(f"Gyro(rad/s) X: {gx:6.2f}{gyro_x_arrow} Y: {gy:6.2f}{gyro_y_arrow} Z: {gz:6.2f}{gyro_z_arrow} | ", end='')
            print(f"Temp: {temp:5.1f}°C / {temp_f:5.1f}°F ║")
            
            # Additional info
            print("╠════════════════════════════════════════════════════════════╣")
            print(f"║ Direction: {overall_direction}                                               ║")
            print(f"║ Web Interface: http://localhost:5000                       ║")
            print("╠════════════════════════════════════════════════════════════╣")
            print("║ [c] Calibrate  [q] Quit                                    ║")
            print("╚════════════════════════════════════════════════════════════╝")
            
            # Use select with a short timeout to allow for responsive exit
            rlist, _, _ = select.select([sys.stdin], [], [], 0.1)
            if rlist:
                key = sys.stdin.read(1)
                if key.lower() == 'q':
                    break
                elif key.lower() == 'c':
                    # Reset terminal for calibration
                    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
                    calibrate_sensor(mpu)
                    # Set back to raw mode
                    tty.setraw(sys.stdin.fileno())
            
            # Reduce flicker by using a slightly longer sleep
            time.sleep(0.05)  # 50ms instead of 0.2s
            
    except Exception as e:
        logger.error(f"Console mode error: {e}")
    finally:
        # Always restore terminal settings
        try:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
            print("\nExiting console mode...")
        except:
            pass
    
    # Ensure global running flag is set to False
    global running
    running = False

def signal_handler(sig, frame):
    """Handle Ctrl+C with improved safety"""
    global running
    
    # Avoid nested prints or repeated calls
    if running:
        running = False
        sys.stdout.write("\nInterrupted. Shutting down...\n")
        sys.stdout.flush()
        
        # Attempt a clean exit
        try:
            # Cancel any blocking operations
            sys.exit(0)
        except:
            pass
