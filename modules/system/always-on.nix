{ ... }:

{
  services.logind = {
    idleAction = "ignore";  # never auto-suspend due to inactivity
    idleActionSec = "0";
  };
}