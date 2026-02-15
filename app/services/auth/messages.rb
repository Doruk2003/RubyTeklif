module Auth
  module Messages
    SESSION_TIMEOUT = "Oturum süreniz doldu. Lütfen tekrar giriş yapın.".freeze
    SESSION_ENDED = "Oturumunuz sona erdi. Lütfen tekrar giriş yapın.".freeze
    SESSION_REFRESH_FAILED = "Oturum yenilenemedi. Lütfen tekrar giriş yapın.".freeze

    ACCOUNT_DISABLED = "Hesabınız devre dışı.".freeze
    UNAUTHORIZED = "Bu işlem için yetkiniz yok.".freeze

    LOGIN_FAILED_PREFIX = "Giriş yapılamadı".freeze
    RECOVERY_EMAIL_REQUIRED = "Lütfen e-posta adresinizi girin.".freeze
    RECOVERY_SENT = "Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.".freeze
    RECOVERY_FAILED_PREFIX = "Şifre sıfırlama e-postası gönderilemedi".freeze
    UNEXPECTED_ERROR = "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.".freeze
  end
end
