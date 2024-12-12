from selenium import webdriver
from selenium.webdriver.common.by import By


def test_example():
    # Вказуємо шлях до драйвера браузера
    driver = webdriver.Chrome(executable_path="/path/to/chromedriver")

    # Відкриваємо веб-сторінку
    driver.get("http://example.com")

    # Знаходимо елемент на сторінці
    element = driver.find_element(By.NAME, "q")

    # Вводимо текст у поле введення
    element.send_keys("Hello, world!")

    # Закриваємо браузер
    driver.quit()
