# home-manager/utilities/devshells/ml-devshell.nix
# Python machine learning environment
#
# Installs the full ML stack globally so jupyter-lab and all packages are
# always available (including when opening .ipynb files via xdg-open).
# The ml-dev script drops you into a shell scoped to this environment.
#
# Usage:
#   $ ml-dev
#   (enters a subshell with the full ML environment)
#   $ jupyter lab          # start JupyterLab
#   $ exit
#   (returns to normal shell)
{pkgs, ...}: let
  mlPython = pkgs.python312.withPackages (
    ps:
      with ps; [
        # Core data science
        numpy
        pandas
        scipy

        # Machine learning
        scikit-learn

        # Visualization
        matplotlib
        seaborn
        plotly

        # Jupyter
        jupyterlab
        ipykernel
        ipywidgets

        # Utilities
        black
        pip
      ]
  );

  mlDevShell = pkgs.mkShell {
    packages = [mlPython];
  };
in {
  # Install globally so `jupyter-lab` is on PATH for xdg-open / MIME association.
  home.packages = [
    mlPython
    (pkgs.writeShellScriptBin "ml-dev" ''
      # Enter the ML Python environment
      # Defined in: home-manager/utilities/devshells/ml-devshell.nix
      exec nix-shell ${mlDevShell.drvPath} --command zsh
    '')
  ];
}
