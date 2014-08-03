# Copyright (c) 2011-2012 Edwin Chen
# Copyright (c) 2014 Mikeqin 

include $(TOPDIR)/rules.mk

PKG_NAME:=wrtiot
PKG_VERSION:=0.1-IoT
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/wrtiot
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+libdaemon +liblua
  TITLE:=WRTIOT -- OpenWrt IOT Project
  MAINTAINER:=Mikeqin <Fengling.Qin@gmail.com>
endef

define Package/wrtiot/description
	Code for wrtiot project.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
	$(CP) ./luasrc/* $(PKG_BUILD_DIR)/
	$(CP) ./config/* $(PKG_BUILD_DIR)/
endef

#define Build/Compile
#endef
BUILD_TIME:=$(shell date)

define Package/wrtiot/install
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wrtiot.uci $(1)/etc/config/wrtiot
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wrtiot.init $(1)/etc/init.d/wrtiot

	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/luad $(1)/usr/sbin/
	$(LN) /usr/sbin/luad $(1)/usr/sbin/IoTd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/IoTd.lua $(1)/usr/sbin/

	$(INSTALL_DIR) $(1)/usr/lib/lua/wrtiot
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/wrtiot/*.lua $(1)/usr/lib/lua/wrtiot/
endef

$(eval $(call BuildPackage,wrtiot))
