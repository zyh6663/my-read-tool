api:
	cd server && go run cmd/main.go

app:
	cd app && flutter run -d web-server --web-port 8081 --web-hostname 0.0.0.0
export PATH="$PATH:/sdks/flutter/bin:/opt/flutter/bin:/usr/local/flutter/bin:/home/codespace/.flutter/bin:/home/codespace/flutter/bin"
