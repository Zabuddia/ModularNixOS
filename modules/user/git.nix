{ u, ... }:
{
  programs.git = {
    enable = true;
    userName = u.fullName;
    userEmail = u.email;
    extraConfig.init.defaultBranch = "main";
  };
}
