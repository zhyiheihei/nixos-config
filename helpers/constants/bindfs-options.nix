_: rec {
  bindfsMountOptions = bindfsMountOptions' [
    "force-user=zhyi"
    "force-group=zhyi"
    "create-for-user=root"
    "create-for-group=root"
  ];

  bindfsMountOptions' =
    args:
    args
    ++ [
      "chown-ignore"
      "chgrp-ignore"
      "xattr-none"
      "x-gvfs-hide"
      "x-gdu.hide"
      "multithreaded"
    ];
}
