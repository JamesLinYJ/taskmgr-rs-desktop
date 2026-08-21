// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Vulkan 物理设备清单
//
//   文件:       crates/taskmgr-linux/src/vulkan.rs
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Vulkan Loader 1.4.350；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Vulkan 1.1；VK_EXT_pci_bus_info
// --------------------------------------------------------------------------

//! 运行时加载 Vulkan Loader，并仅通过 `VK_EXT_pci_bus_info` 将物理设备精确关联到 DRM PCI 设备。
//! 不存在扩展或无法唯一关联时不猜测设备，调用方保留“不可用”语义。

use ash::{Entry, vk};
use std::collections::HashMap;

#[derive(Clone, Debug)]
pub(crate) struct VulkanDevice {
    pub(crate) name: String,
    pub(crate) api_version: String,
}

pub(crate) fn discover() -> Result<HashMap<String, VulkanDevice>, String> {
    // SAFETY: `Entry::load` loads the platform Vulkan loader and owns it for the whole query.
    let entry = unsafe { Entry::load() }.map_err(|error| format!("load Vulkan: {error}"))?;
    // SAFETY: `entry` owns a successfully loaded Vulkan loader. Ash performs the null-function
    // check before calling `vkEnumerateInstanceVersion`, and no application pointer is supplied.
    let loader_version = unsafe { entry.try_enumerate_instance_version() }
        .map_err(|error| format!("query Vulkan loader version: {error:?}"))?
        .unwrap_or(vk::API_VERSION_1_0);
    if loader_version < vk::API_VERSION_1_1 {
        return Ok(HashMap::new());
    }
    let application_info = vk::ApplicationInfo::default()
        .application_name(c"taskmgr-rs")
        .application_version(1)
        .engine_name(c"taskmgr-rs")
        .engine_version(1)
        .api_version(vk::API_VERSION_1_1);
    let create_info = vk::InstanceCreateInfo::default().application_info(&application_info);
    // SAFETY: create info points to stack data that lives for the complete call.
    let instance = unsafe { entry.create_instance(&create_info, None) }
        .map_err(|error| format!("create Vulkan instance: {error:?}"))?;
    let result = query_devices(&instance);
    // SAFETY: no Vulkan child objects survive `query_devices`.
    unsafe { instance.destroy_instance(None) };
    result
}

fn query_devices(instance: &ash::Instance) -> Result<HashMap<String, VulkanDevice>, String> {
    // SAFETY: the instance is valid and owns the returned opaque handles.
    let devices = unsafe { instance.enumerate_physical_devices() }
        .map_err(|error| format!("enumerate Vulkan physical devices: {error:?}"))?;
    let mut result = HashMap::new();
    for device in devices {
        // SAFETY: `device` was returned by this instance.
        let extensions = unsafe { instance.enumerate_device_extension_properties(device) }
            .map_err(|error| format!("enumerate Vulkan device extensions: {error:?}"))?;
        let has_pci_bus_info = extensions.iter().any(|extension| {
            extension
                .extension_name_as_c_str()
                .is_ok_and(|name| name == vk::EXT_PCI_BUS_INFO_NAME)
        });
        if !has_pci_bus_info {
            continue;
        }
        let mut pci = vk::PhysicalDevicePCIBusInfoPropertiesEXT::default();
        let device_properties = {
            let mut properties = vk::PhysicalDeviceProperties2::default().push_next(&mut pci);
            // SAFETY: the pNext chain is correctly typed and writable for the duration of the
            // call. The copied base properties contain no pointers into this temporary chain.
            unsafe { instance.get_physical_device_properties2(device, &mut properties) };
            properties.properties
        };
        let slot = format!(
            "{:04x}:{:02x}:{:02x}.{}",
            pci.pci_domain, pci.pci_bus, pci.pci_device, pci.pci_function
        );
        let name = device_properties
            .device_name_as_c_str()
            .map_err(|error| format!("Vulkan returned an unterminated device name: {error}"))?
            .to_string_lossy()
            .into_owned();
        let version = device_properties.api_version;
        result.insert(
            slot,
            VulkanDevice {
                name,
                api_version: format!(
                    "Vulkan {}.{}.{}",
                    vk::api_version_major(version),
                    vk::api_version_minor(version),
                    vk::api_version_patch(version)
                ),
            },
        );
    }
    Ok(result)
}
