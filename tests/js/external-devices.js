.import "../../ui/js/Mounts.js" as Mounts

function run(check) {
    var internal = {name: "sda", type: "disk", rm: false, hotplug: false, tran: "sata"}
    var ssd = {name: "sdb", type: "disk", rm: false, hotplug: true, tran: "usb",
               model: "SAMSUNG 512GB", children: [
                   {name: "sdb1", type: "part", rm: false, label: "512GB",
                    mountpoint: "/run/media/jehuty/512GB"}]}
    function rows(nodes) { return Mounts.parseDevices(JSON.stringify({blockdevices: nodes})) }
    var found = rows([ssd, internal])
    check("USB SSD is included with the internal disk", found.length, 2)
    check("USB SSD listed first cannot become the internal disk", found[0].device, "/dev/sda")
    check("SSD partition inherits USB and hotplug from parent", found[1].device, "/dev/sdb1")
    check("SSD opens its real mount point", found[1].path, "/run/media/jehuty/512GB")
    check("SSD retains its filesystem label", found[1].label, "512GB")
    ssd.hotplug = false
    check("USB transport alone recognizes a fixed-media SSD", rows([ssd]).length, 1)

    // Bare hotplug is no signal, and reading it as one was a defect: a hot-swap SATA bay reports
    // hotplug=true and is an internal disk, so it used to lose its own row and hand its partitions
    // an eject control. Upstream PR #74 draws the line at rm, tran and the subsystems chain.
    var swapBay = {name: "sdc", type: "disk", rm: false, hotplug: true, tran: "sata",
                   subsystems: "block:scsi:pci",
                   children: [{name: "sdc1", type: "part", rm: false, hotplug: false,
                               tran: null, subsystems: "block:scsi:pci", mountpoint: "/data"}]}
    check("a hotplug SATA bay is still the internal disk", rows([swapBay])[0].kind, "disk")
    check("and it grows no ejectable volume", rows([swapBay]).length, 1)

    // A bridge that names no transport of its own still names usb in the chain it hangs off.
    var bridge = {name: "sdd", type: "disk", rm: false, hotplug: false, tran: null,
                  subsystems: "block:scsi:usb:pci", model: "WDC",
                  children: [{name: "sdd1", type: "part", rm: false, hotplug: false, tran: null,
                              subsystems: "block:scsi:pci", label: "Passport"}]}
    check("a usb subsystems chain marks a bridge external", rows([bridge])[0].label, "Passport")
    check("and its partition inherits that answer", rows([bridge])[0].device, "/dev/sdd1")

    ssd.children[0].mountpoint = null
    check("unmounted external partition remains available", rows([ssd])[0].mounted, false)
    delete ssd.children
    check("unpartitioned external SSD is a volume", rows([ssd])[0].device, "/dev/sdb")
    check("unpartitioned external SSD is not the internal disk", rows([ssd])[0].kind, "volume")
    check("internal SATA disk remains the system row", rows([internal])[0].kind, "disk")
}
