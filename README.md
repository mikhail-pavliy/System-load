# System-load
Работа с загрузчиком
# 1. Попасть в систему без пароля несколькими способами
#    1.1  Способ 1. init=/bin/sh
Во время появления меню GRUB нажмите клавишу «a», чтобы остановить загрузку 
Затем нажмите «e» для перехода к редактированию параметров загрузки (скрин 1)
На экране отсутствует нужная нам строка, нужно пролиснуть курсорными клавишами вниз и найти строку, начинающуюся с linux16. (скрин2)
Перейдём в конец этой строки, поставим пробел и допишем:  init=/bin/sh и нажимаем сtrl-x для загрузки в систему
Проверим права на запись:  
```ruby
mount | grep root
```
Как можно убедиться, права на запись отсутствуют. (скрин3) Перемонтируем файловую систему с правами записи:
```ruby
mount -rw -o remount /
````
Сменим пароль
```ruby
passwd
```
Пароль изменён, но дело ещё не закончено. Нам нужно переобозначить контекст SELinux. Если мы не выполним переобозначение всего контекста SELinux, мы не сможем войти используя новый пароль. Для этого:
```ruby
touch /.autorelabel
```
Для выхода набираем:
```ruby
sync
umount /
```
# 1.2 Способ 2. rd.break
В конце строки начинающейся с linux16 добавляем rd.break и нажимаем сtrl-x для загрузки в систему. Попадаем в emergency mode. Наша корневая файловая система смонтирована опять же в режиме Read-Only. 
Выполним команду перемонтирования корня для чтения и записи:
```ruby
- mount -o remount,rw /sysroot, далее chroot /sysroot.
```
Теперь мы можем поменять пароль, выполнив команду:
```ruby
passwd
```
После смены пароля необходимо создать скрытый файл .autorelabel в /, выполнив 
```ruby
touch /.autorelabel
```
Делаем перзагрузку.
теперь заходим под root, введя измененный пароль. 
# 1.3 Способ 3. rw init=/sysroot/bin/sh
В  строке начинающейся с linux16 заминяем  ro на rw init=/sysroot/bin/sh и нажимаем сtrl-x для загрузки в систему
От прошлого примера отличается только тем, что файловая система сразу смонтирована в режим Read-Write

# 2. Установить систему с LVM, после чего переименовать VG
```ruby
[root@localhost ~]# vgs
VG     #PV #LV #SN Attr   VSize   VFree
centos   1   3   0 wz--n- 125.80g 4.00m
```
Обращаем внимание на строку с именем centos
Приступим к переименованию:
```ruby
[root@localhost ~]# vgrename centos OtusRoot
Volume group "centos" successfully renamed to "OtusRoot"
```
Изменяем конфигурационные файлы:
```ruby
[root@localhost ~]# sed -i s/centos/otusroot/g /boot/grub2/grub.cfg  sed -i s/centos/otusroot/g /etc/fstab
```
Пересоздаем initrd image, чтобы он знал новое название Volume Group
```ruby
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
....
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-693.el7.x86_64.img' done ***
```
После чего можем перезагружаемся и если все сделано правильно успешно грузимся с новым именем Volume Group и проверяем
```ruby
[root@localhost ~]# vgs
VG     #PV #LV #SN Attr   VSize   VFree
OtusRoot    1   3   0 wz--n- 125.80g 4.00m
```
# 3. Добавить модуль в initrd

Скрипты модулей хранятся в каталоге /usr/lib/dracut/modules.d/. Для того чтобы добавить свой модуль создаем там папку с именем 01test:
```ruby
[root@localhost ~]# mkdir /usr/lib/dracut/modules.d/01test
````
В нее поместим два скрипта:

1.module-setup.sh - который устанавливает модуль и вызывает скрипт test.sh

2.test.sh - собственно сам вызываемый скрипт, в нём у нас рисуется пингвинчик.
```ruby
[root@localhost 01test]# ls -a

.  ..  module-setup.sh  test.sh
```
В скрипт module-setup.sh вписываем:


check() { # Функция, которая указывает что модуль должен быть включен по умолчанию
    return 0
}

depends() { # Выводит все зависимости от которых зависит наш модуль
    return 0
}

install() {
    inst_hook cleanup 00 "${moddir}/test.sh" # Запускает скрипт
}```  


В файле test.sh:
```ruby

```#!/bin/bash

exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
cat <<'msgend'
Hello! You are in dracut module!
 ___________________
< I'm dracut module >
 -------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."   

```

Теперь пересоберем образ initrd
```ruby
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
````
после чего перезагружаемся и смотрим на нашего пингвина
# 4.  Сконфигурировать систему без отдельного раздела с /boot, а только с LVM
Готвоим vagrant файл
командой lsblk смотрим наш конфиг после создания машины
```ruby
[vagrant@sytemload ~]$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk
└─sda1   8:1    0  40G  0 part /
sdb      8:16   0   1G  0 disk
```
устанавливаем пропатченный grub
```ruby
[root@sytemload vagrant]# yum-config-manager --add-repo=https://yum.rumyantsev.com/centos/7/x86_64/
Loaded plugins: fastestmirror
adding repo from: https://yum.rumyantsev.com/centos/7/x86_64/

[yum.rumyantsev.com_centos_7_x86_64_]
name=added from: https://yum.rumyantsev.com/centos/7/x86_64/
baseurl=https://yum.rumyantsev.com/centos/7/x86_64/
enabled=1
```
Смотрю названия дисков в системе
```ruby
[root@sytemload vagrant]# fdisk -l

Disk /dev/sda: 42.9 GB, 42949672960 bytes, 83886080 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk label type: dos
Disk identifier: 0x0009ef1a

   Device Boot      Start         End      Blocks   Id  System
/dev/sda1   *        2048    83886079    41942016   83  Linux

Disk /dev/sdb: 1073 MB, 1073741824 bytes, 2097152 sectors
Units = sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```
делаем операцию с дискми
