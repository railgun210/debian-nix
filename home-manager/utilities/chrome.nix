# home-manager/utilities/chrome.nix
# Google Chrome with force-installed extensions.
#
# Extension management: programs.google-chrome.extensions is documented to not
# work with the proprietary Chrome package, so we write Chrome's managed policy
# JSON directly. Chrome reads all *.json files under
# ~/.config/google-chrome/policies/managed/ and auto-installs/updates the listed
# extensions on each launch.
#
# Bookmark sync with Firefox: Firefox Sync and Google Sync are incompatible
# protocols. Raindrop.io (installed below) serves as the cross-browser bookmark
# manager — also add the Raindrop extension to Firefox ESR from addons.mozilla.org.
{pkgs, ...}: let
  updateUrl = "https://clients2.google.com/service/update2/crx";
  forcelist = map (id: "${id};${updateUrl}") [
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
    "ldgfbffkinooeloadekpmfoklnobpien" # Raindrop.io (cross-browser bookmarks)
    "olobfjbmcfjhkdlcpcklaohoofjbegio" # Sluka (language-learning reader)
    "onekplkgdfafjkeellaojjobdjffjkpo" # uBlock Origin (ad-blocker)
  ];
in {
  home.packages = [pkgs.google-chrome];

  xdg.configFile."google-chrome/policies/managed/extensions.json".text =
    builtins.toJSON {ExtensionInstallForcelist = forcelist;};
}
