{ inputs, ... }:
final: prev: {
  dreame-vacuum = final.callPackage ../pkgs/dreame-vacuum { };
}
