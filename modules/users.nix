{ pkgs, ulist, ... }:
{
  users.mutableUsers = false;
  users.users = builtins.listToAttrs (map (u: {
    name = u.name;
    value = {
      isNormalUser = true;
      description  = u.fullName or u.name;
      extraGroups  = u.groups or [];
      shell        = pkgs.${u.shell};
      hashedPassword = u.hashedPassword;
    };
  }) ulist.users);
}