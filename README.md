Разворачивает Microsoft Certification Authority в конфиге root CA + subordinate CA.
Данный скрипт помогает быстро развернуть центр сертификации для тестовых лаб и стендов (например для выдачи сертфикатов RDS фермы). Запускается с машины root CA.
Тестировался и работает на WinServer 2019. RootCA (standalone, workgroup). Subordinate CA (enterprise, располагается на DC)
