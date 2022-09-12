# Copyright (C) 2021

include $(TOPDIR)/rules.mk

PKG_NAME:=v2ray-plugin
PKG_VERSION:=5.1.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/teddysun/v2ray-plugin/tar.gz/v$(PKG_VERSION)?
PKG_HASH:=8793a4d94131271f3c48b7e2a4d9c0b97148192b96e275717fbc621d8927f7de

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Bobby <zhang.deplives@gmail.com>

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

GO_PKG:=github.com/shadowsocks/v2ray-plugin
GO_PKG_LDFLAGS_X:=main.VERSION=v$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/v2ray-plugin
    SECTION:=net
    CATEGORY:=Network
    SUBMENU:=Web Servers/Proxies
    TITLE:=SIP003 plugin for shadowsocks, based on v2ray
    URL:=https://github.com/teddysun/v2ray-plugin
    DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

$(eval $(call GoBinPackage,v2ray-plugin))
$(eval $(call BuildPackage,v2ray-plugin))
