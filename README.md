# Cloudflare IPv6 Dynamic DNS on macOS 11
Version 0.0.1
Features:
- Real time update instead of polling every 5 minutes (such as [ddclient](https://ddclient.net))
- Written in Swift using [SystemConfiguration Framework](https://developer.apple.com/documentation/systemconfiguration), [Alamofire](https://github.com/Alamofire/Alamofire) and [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON).

## Required configuration file
`/usr/local/etc/cloudflare_ipv6_ddns.json`
```json
{
  "NET_IF": "en0",
  "ZONE_ID": "xxxx",
  "RECORD_ID": "xxxx",
  "API_TOKEN": "xxxx"
}
```

## Installation
```
brew tap xiruizhao/cloudflare-ipv6-ddns
brew install cloudflare-ipv6-ddns
```
