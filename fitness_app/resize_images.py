import os
from PIL import Image

# Path to the directory containing images
image_dir = r"c:\src\training\fitness_app\image\icons"
max_size = (256, 256)

print(f"Resizing images in {image_dir}...")

count = 0
for filename in os.listdir(image_dir):
    if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
        filepath = os.path.join(image_dir, filename)
        try:
            with Image.open(filepath) as img:
                # Resize keeping aspect ratio
                img.thumbnail(max_size, Image.Resampling.LANCZOS)
                
                # Save to a temporary file first to avoid locking issues
                temp_filepath = filepath + ".tmp" + os.path.splitext(filename)[1]
                img.save(temp_filepath, optimize=True, quality=85)
            
            # Replace the original file with the temporary file
            os.replace(temp_filepath, filepath)
            print(f"Resized: {filename}")
            count += 1
        except Exception as e:
            print(f"Error resizing {filename}: {e}")
            if os.path.exists(filepath + ".tmp" + os.path.splitext(filename)[1]):
                try:
                    os.remove(filepath + ".tmp" + os.path.splitext(filename)[1])
                except:
                    pass

print(f"Finished. Resized {count} images.")
