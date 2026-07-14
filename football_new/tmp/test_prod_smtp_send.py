import asyncio

from api.services.email import SMTPEmailService


async def main() -> None:
    svc = SMTPEmailService()
    ok = await svc._send_email(
        "support@edgescore.pro",
        "EdgeScore SMTP test",
        "<html><body><h3>SMTP test OK</h3><p>Sent from production API on 2026-06-05.</p></body></html>",
    )
    print(
        {
            "sent": ok,
            "smtp_server": svc.smtp_server,
            "smtp_port": svc.smtp_port,
            "username": svc.username,
            "from_email": svc.from_email,
        }
    )


if __name__ == "__main__":
    asyncio.run(main())
