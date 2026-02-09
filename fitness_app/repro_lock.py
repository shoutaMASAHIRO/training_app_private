from PIL import Image
import os

filename = "test_lock.png"
# Create dummy image
img = Image.new('RGB', (100, 100), color = 'red')
img.save(filename)

try:
    with Image.open(filename) as img:
        print("Opened image.")
        img.save(filename)
        print("Saved image over itself successfully (unexpected on Windows).")
except Exception as e:
    print(f"Caught expected error: {e}")
finally:
    if os.path.exists(filename):
        try:
            os.remove(filename)
        except:
            pass
