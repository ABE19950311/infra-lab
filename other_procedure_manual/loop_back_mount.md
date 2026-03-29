■ 前提条件
/dev/ 以下に、ループバックファイルが存在していること
存在していない場合、losetup -f で未使用ファイルを確認する

1. loopデバイス用の空ファイルを作成する
```
# dd if=/dev/zero of=/disk.img bs=1M count=1024
# ls -l /disk.img
```

2. ループバックファイルと空ファイルを関連付ける
```
# losetup -f /disk.img
# losetup -l
```

3. ファイルシステムを設定する
```
// losetup -lで確認したloopデバイスを指定
# mkfs -t ext4 /dev/loop0
```

4. ループバックファイルをmountする
```
// マウントポイント作成
# mkdir -p /mnt/disk
# mount -t ext4 /dev/loop0 /mnt/disk
# mount
# df -PhT
```


---

解除
1. アンマウントする
```
# umount マウントポイント
※target is busyが出る場合は、マウントポイント以外にcdしてからumountする
```

2. ループバックファイル解除
```
# losetup -l
# losetup -d 解除対象ループデバイス
# losetup -l
```

3. ループバック用空ファイル削除
```
# rm /disk.img
```

4. マウントポイント削除
```
# rm -rf /mnt/disk
```