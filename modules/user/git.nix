{ u, ... }:
{
  programs.git = {
    enable = true;

    settings = {
      user.name  = u.fullName;
      user.email = u.email;

      init.defaultBranch = "main";
    };
  };
}