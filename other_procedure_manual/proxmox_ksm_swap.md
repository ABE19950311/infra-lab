nano /etc/ksmtuned.conf
-------------------------
# Configuration file for ksmtuned.

# How long ksmtuned should sleep between tuning adjustments
# KSM_MONITOR_INTERVAL=60

# Millisecond sleep between ksm scans for 16Gb server.
# Smaller servers sleep more, bigger sleep less.
KSM_SLEEP_MSEC=200  # 修正

# KSM_NPAGES_BOOST=300
# KSM_NPAGES_DECAY=-50
# KSM_NPAGES_MIN=64
KSM_NPAGES_MAX=1250

KSM_THRES_COEF=20
# KSM_THRES_CONST=2048

# The metric used to calculate how much memory is used by a QEMU process
# The proportional set size (pss) or the residential (rsz) ones are good fits.
# KSM_PS_METRIC=pss

# uncomment the following if you want ksmtuned debug info

# LOGFILE=/var/log/ksmtuned
# DEBUG=1
-------------------------

systemctl restart ksmtuned
cat /sys/kernel/mm/ksm/run
# 1 と出力されればOK、restartからしばらく待つ



nano /etc/sysctl.conf
-----------------------
#

###################################################################
# Magic system request Key
# 0=disable, 1=enable all, >1 bitmask of sysrq functions
# See https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
# for what other values do
#kernel.sysrq=438

vm.swappiness = 10  # 追記
-----------------------

sysctl -p
# vm.swappiness = 10 と出力されればOK