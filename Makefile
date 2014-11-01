#
# Copyright (C) 2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=wrtiot
PKG_VERSION:=0.19
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://www.intra2net.com/en/developer/libftdi/download/
PKG_MD5SUM:=e6e25f33b4327b1b7aa1156947da45f3

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/wrtiot
	SECTION:=libs
	CATEGORY:=Libraries
	DEPENDS:=+libusb +libusb-compat
	TITLE:=library to talk to FTDI chips
	URL:=http://www.intra2net.com/en/developer/wrtiot/
endef

define Package/wrtiot/description
	wrtiot - FTDI USB driver with bitbang mode
	wrtiot is an open source library to talk to FTDI chips: FT232BM, FT245BM, FT2232C, FT2232H, FT4232H, FT2232D and FT245R, including the popular bitbang mode.
	The library is linked with your program in userspace, no kernel driver required.
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/
	$(CP) $(PKG_INSTALL_DIR)/usr/include/ftdi.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/wrtiot.{a,so} $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/wrtiot.so* $(1)/usr/lib/
endef

define Package/wrtiot/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/wrtiot.so.* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,wrtiot))

