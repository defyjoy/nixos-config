# Machine-specific GPU module. install.sh rewrites this to `{ imports = [ ./nvidia.nix ]; }`
# when it finds an NVIDIA card; otherwise (Apple Silicon, AMD/Intel, VMs) it stays empty.
{ }
