import smtplib

SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = "grafsuvorov111@gmail.com"
SMTP_PASS = "aotuyyrqiehqlhvw"

server = smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10)
server.set_debuglevel(1)  # <<< ВАЖНО: покажет лог
server.starttls()
server.login(SMTP_USER, SMTP_PASS)
server.sendmail(
    SMTP_USER,
    SMTP_USER,
    "Subject: Test\n\nHello from SMTP test"
)
server.quit()
