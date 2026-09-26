# home-manager/utilities/default-apps.nix
# XDG default application associations. The LibreOffice and Nautilus desktop
# files come from apt; jupyterlab.desktop from devshells/ml-devshell.nix.
{...}: {
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "inode/directory" = ["org.gnome.Nautilus.desktop"];

    # Word / Writer (.doc .docx .docm .dotx .dotm)
    "application/msword" = ["libreoffice-writer.desktop"];
    "application/vnd.ms-word.document.macroEnabled.12" = ["libreoffice-writer.desktop"];
    "application/vnd.ms-word.template.macroEnabled.12" = ["libreoffice-writer.desktop"];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["libreoffice-writer.desktop"];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = ["libreoffice-writer.desktop"];

    # Excel / Calc (.xls .xlsx .xlsm .xltx .xltm)
    "application/vnd.ms-excel" = ["libreoffice-calc.desktop"];
    "application/vnd.ms-excel.sheet.macroEnabled.12" = ["libreoffice-calc.desktop"];
    "application/vnd.ms-excel.template.macroEnabled.12" = ["libreoffice-calc.desktop"];
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["libreoffice-calc.desktop"];
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = ["libreoffice-calc.desktop"];

    # Jupyter Notebooks (.ipynb)
    "application/x-ipynb+json" = ["jupyterlab.desktop"];

    # PowerPoint / Impress (.ppt .pptx .pptm .potx .potm .ppsx .ppsm)
    "application/vnd.ms-powerpoint" = ["libreoffice-impress.desktop"];
    "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = ["libreoffice-impress.desktop"];
    "application/vnd.ms-powerpoint.template.macroEnabled.12" = ["libreoffice-impress.desktop"];
    "application/vnd.ms-powerpoint.slideshow.macroEnabled.12" = ["libreoffice-impress.desktop"];
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["libreoffice-impress.desktop"];
    "application/vnd.openxmlformats-officedocument.presentationml.template" = ["libreoffice-impress.desktop"];
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = ["libreoffice-impress.desktop"];
  };
}
