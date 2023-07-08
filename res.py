import argparse
import time
import pywinauto
import pyautogui


def switch_resolution(resolution):
    # Open NVIDIA Control Panel
    pyautogui.hotkey('win', 's')
    pyautogui.typewrite('NVIDIA Control Panel')
    time.sleep(0.5)
    pyautogui.press('enter')
    time.sleep(3)

    # Find the NVIDIA Control Panel window
    app = pywinauto.Desktop(backend='uia').window(title='NVIDIA Systemsteuerung')
    app.set_focus()

    # Select "Change resolution"
    app.child_window(title='Auflösung ändern', found_index=0).click_input()

    # Find and click the matching resolution
    resolution_item = app.child_window(title_re=f'.*{resolution}.*', found_index=0)
    resolution_item.click_input()

    # Click "Apply"
    app.child_window(title='Übernehmen').click_input()

    # Close the NVIDIA Control Panel
    app.close()


if __name__ == "__main__":
    # Create the argument parser
    parser = argparse.ArgumentParser(description='Switch resolution using NVIDIA Control Panel.')

    # Add the resolution argument
    parser.add_argument('resolution', choices=['1920', '1440'], help='Resolution to switch to (1920 or 1440)')

    # Parse the command-line arguments
    args = parser.parse_args()

    # Call the function to switch the resolution
    switch_resolution(args.resolution)
