api:
	cd server && go run cmd/main.go

app:
	cd app && flutter run -d web-server --web-port 8081 --web-hostname 0.0.0.0
