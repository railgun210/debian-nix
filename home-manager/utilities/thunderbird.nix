# home-manager/utilities/thunderbird.nix
# Plain Thunderbird email client and default email application.
{...}: {
  programs.thunderbird = {
    enable = true;

    profiles.default = {
      isDefault = true;
    };
  };

  # Make Thunderbird the default handler for compose links and email files.
  xdg.mimeApps.defaultApplications = {
    "message/rfc822" = ["thunderbird.desktop"];
    "x-scheme-handler/mailto" = ["thunderbird.desktop"];
  };
}
