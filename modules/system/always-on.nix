{ ... }:

{
  services.logind.settings = {
    Login = {
      IdleAction = "ignore";
      IdleActionSec = 0;
    };
  };
}