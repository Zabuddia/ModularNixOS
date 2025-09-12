{ ... }:
{
  programs.librewolf = {
    enable = true;

    policies = {
      Cookies = {
        Behavior = "reject";
        Allow = [
          "https://chatgpt.com"
          "https://github.com"
        ];
      };
    };
  };
}
