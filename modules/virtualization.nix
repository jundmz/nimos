{ username, ...}:
{
  
  virtualisation.docker = {
  enable = true;
};

# Optional: Add your user to the "docker" group to run docker without sudo
users.users.${username}.extraGroups = [ "docker" ];
}
