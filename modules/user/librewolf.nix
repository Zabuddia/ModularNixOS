{ ... }:
{
  programs.librewolf = {
    enable = true;

    policies.Cookies.Allow = [
      "https://github.com"
      "https://chatgpt.com"
      "https://learningsuite.byu.edu"
    ];
  };
}