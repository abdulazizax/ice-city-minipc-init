#!/bin/bash

# Docker Installation Script for Ubuntu
# This script installs Docker CE and Docker Compose plugin with fallback options

echo "Starting Docker installation..."

# Function to install Docker via snap (fallback method)
install_docker_snap() {
    echo "Installing Docker via snap (fallback method)..."
    sudo snap install docker
    sudo groupadd -f docker
    sudo usermod -aG docker $USER
    echo "Docker installed via snap successfully!"
    echo "Please log out and back in, then test with: sudo docker run --rm hello-world"
    return 0
}

# Function to try apt installation
install_docker_apt() {
    echo "Attempting Docker installation via apt..."
    
    # Update package index with retries
    echo "Updating package index..."
    for i in {1..3}; do
        if sudo apt update; then
            break
        else
            echo "Attempt $i failed, retrying in 5 seconds..."
            sleep 5
        fi
    done

    # Install prerequisite packages
    echo "Installing prerequisite packages..."
    if ! sudo apt install -y ca-certificates curl gnupg; then
        echo "Failed to install prerequisites via apt"
        return 1
    fi

    # Create directory for Docker's GPG key
    echo "Setting up Docker's GPG key..."
    if ! sudo install -m 0755 -d /etc/apt/keyrings; then
        echo "Failed to create keyrings directory"
        return 1
    fi

    # Add Docker's official GPG key
    echo "Downloading Docker GPG key..."
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        echo "Failed to download Docker GPG key"
        return 1
    fi

    # Add Docker repository
    echo "Adding Docker repository..."
    if ! echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release; echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        echo "Failed to add Docker repository"
        return 1
    fi

    # Update package index with Docker packages
    echo "Updating package index with Docker packages..."
    for i in {1..3}; do
        if sudo apt update; then
            break
        else
            echo "Update attempt $i failed, retrying in 5 seconds..."
            sleep 5
            if [ $i -eq 3 ]; then
                echo "Failed to update package index after 3 attempts"
                return 1
            fi
        fi
    done

    # Install Docker Engine, CLI, containerd, and Docker Compose plugin
    echo "Installing Docker packages..."
    if ! sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        echo "Failed to install Docker packages via apt"
        return 1
    fi

    # Add current user to docker group
    echo "Adding current user to docker group..."
    sudo usermod -aG docker $USER

    echo "Docker installation via apt completed successfully!"
    return 0
}

# Main installation logic
echo "Checking internet connectivity..."
if ! ping -c 1 google.com &> /dev/null; then
    echo "Warning: Internet connectivity issues detected"
fi

# Try apt installation first
if install_docker_apt; then
    echo ""
    echo "✅ Docker installation completed successfully via apt!"
    echo ""
    echo "IMPORTANT: You may need to log out and back in (or restart) for group changes to take effect."
    echo "After that, you can test the installation with: docker run --rm hello-world"
    echo ""
    echo "To apply group changes immediately in this session, run: newgrp docker"
else
    echo ""
    echo "⚠️  Apt installation failed, trying snap installation as fallback..."
    echo ""
    
    if install_docker_snap; then
        echo ""
        echo "✅ Docker installation completed via snap!"
    else
        echo ""
        echo "❌ Both installation methods failed."
        echo "Please check your internet connection and try again."
        echo "You can also try installing manually with:"
        echo "  sudo snap install docker"
        echo "or visit: https://docs.docker.com/engine/install/ubuntu/"
        exit 1
    fi
fi