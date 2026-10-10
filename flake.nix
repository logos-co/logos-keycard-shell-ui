{
  description = "Logos keycard_shell_ui — the Keycard Shell's app: its Shells and the accounts it offers.";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    # Pinned to the module's first branch until it reaches main.
    keycard_shell_module = {
      url = "github:logos-co/logos-keycard-shell-module/eb6bb6fb14a16f102e9a82c5264e80cbc0c21878";
      inputs.logos-module-builder.follows = "logos-module-builder";
    };
  };

  # mkLogosQmlModule assembles the QML into the package, which the .lgx step needs.
  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
