package glyphnet

public let TEMPLATE_CISCO_IOS_SHOW_VERSION: String = #"Value Required VERSION (\d+\.\d+\(\d+\)\S*)
Value SOFTWARE_IMAGE ([^)]+)
Value RELEASE ([^)]+)
Value ROMMON (.+)
Value Required HOSTNAME (\S+)
Value UPTIME (.+?)
Value RUNNING_IMAGE ([^"]+)
Value List HARDWARE (\S+)
Value SERIAL (\S+)
Value CONFIG_REGISTER (\S+)

Start
  ^Cisco IOS Software,.*\(${SOFTWARE_IMAGE}\),\s+Version\s+${VERSION},\s+RELEASE SOFTWARE\s+\(${RELEASE}\)
  ^ROM:\s+${ROMMON}\s*$$
  ^${HOSTNAME}\s+uptime\s+is\s+${UPTIME}\s*$$
  ^System image file is "${RUNNING_IMAGE}"
  ^[Cc]isco\s+${HARDWARE}\s+\(.+\)\s+processor.*
  ^Processor board ID\s+${SERIAL}\s*$$
  ^Configuration register is\s+${CONFIG_REGISTER}\s*$$
"#

public let TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF: String = #"Value Required INTERFACE (\S+)
Value IP_ADDRESS (\S+)
Value OK (\S+)
Value METHOD (\S+)
Value STATUS (administratively down|up|down|reset|deleted)
Value PROTO (up|down)

Start
  ^Interface\s+IP-Address\s+OK\?\s+Method\s+Status\s+Protocol\s*$$
  ^${INTERFACE}\s+${IP_ADDRESS}\s+${OK}\s+${METHOD}\s+${STATUS}\s+${PROTO}\s*$$ -> Record
"#

public let TEMPLATE_CISCO_IOS_SHOW_IP_INTERFACE_BRIEF_LIST: String = #"Value List INTERFACE (\S+)
Value List IP_ADDRESS (\S+)
Value List STATUS (\S+)
Value List PROTO (\S+)

Start
  ^Interface\s+IP-Address\s+OK\?\s+Method\s+Status\s+Protocol\s*$$
  ^${INTERFACE}\s+${IP_ADDRESS}\s+\S+\s+\S+\s+${STATUS}\s+${PROTO}\s*$$
"#
