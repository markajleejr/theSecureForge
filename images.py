import os
import re
import shutil

# Paths (using raw strings to handle Windows backslashes correctly)
posts_dir = r"C:\Users\marka\Documents\theSecureForge\content\posts"
attachments_dir = r"C:\Users\marka\Documents\Mark's Vault\posts\attachments"
static_images_dir = r"C:\Users\marka\Documents\theSecureForge\static\images"

def log_error(message):
    print(f"ERROR: {message}")

def log_info(message):
    print(f"INFO: {message}")

try:
    # Step 1: Process each markdown file in the posts directory
    if not os.path.exists(posts_dir):
        raise FileNotFoundError(f"Posts directory not found: {posts_dir}")

    if not os.path.exists(attachments_dir):
        raise FileNotFoundError(f"Attachments directory not found: {attachments_dir}")

    if not os.path.exists(static_images_dir):
        raise FileNotFoundError(f"Static images directory not found: {static_images_dir}")

    log_info(f"Processing markdown files in: {posts_dir}")
    for filename in os.listdir(posts_dir):
        if filename.endswith(".md"):
            filepath = os.path.join(posts_dir, filename)
            log_info(f"Processing file: {filename}")

            try:
                with open(filepath, "r", encoding="utf-8") as file:
                    content = file.read()

                # Step 2: Find all image links in the format [[image.png]]
                images = re.findall(r'\[\[([^]]*\.png)\]\]', content)
                
                # Step 3: Replace image links and ensure URLs are correctly formatted
                for image in images:
                    markdown_image = f"![Image Description](/images/{image.replace(' ', '%20')})"
                    content = content.replace(f"[[{image}]]", markdown_image)
                    
                    # Step 4: Copy the image to the Hugo static/images directory if it exists
                    image_source = os.path.join(attachments_dir, image)
                    if os.path.exists(image_source):
                        shutil.copy(image_source, static_images_dir)
                        log_info(f"Copied image: {image} to {static_images_dir}")
                    else:
                        log_error(f"Image not found: {image_source}")

                # Step 5: Write the updated content back to the markdown file
                with open(filepath, "w", encoding="utf-8") as file:
                    file.write(content)
                log_info(f"Updated content written to: {filename}")
            except Exception as e:
                log_error(f"Error processing file {filename}: {e}")
    log_info("All markdown files processed successfully.")
except Exception as e:
    log_error(f"Script failed: {e}")
