/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "adc.h"
#include "i2c.h"
#include "i2s.h"
#include "spi.h"
#include "tim.h"
#include "usart.h"
#include "usb_host.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
/* ===== PARAMETER WVAF ===== */
#define WIN_MAX        16
#define WIN_MIN         2
#define DELTA_THRESH   200   /* Threshold perubahan ADC (0-4095) */

/* ===== STATE SENSOR ===== */
#define STATE_NORMAL   0
#define STATE_WARNING  1
#define STATE_DANGER   2

/* ===== PERINTAH AKTUATOR ===== */
#define ACT_NORMAL     0   /* LED GREEN ON, RED OFF, Relay OFF */
#define ACT_WARNING    1   /* LED RED ON,   GREEN OFF, Relay OFF */
#define ACT_DANGER     2   /* LED RED ON,   GREEN OFF, Relay ON */
#define ACT_IDLE       3   /* Semua OFF */
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
/* ===== O(1) STATE MATRIX =====
 * Baris : Sensor State (0=Normal, 1=Warning, 2=Danger)
 * Kolom : System Mode  (0=Auto,   1=Manual,  2=Safe)   */
const uint8_t state_matrix[3][3] = {
/*               Auto          Manual        Safe      */
/* Normal  */ { ACT_NORMAL,  ACT_NORMAL,  ACT_IDLE   },
/* Warning */ { ACT_WARNING, ACT_WARNING, ACT_IDLE   },
/* Danger  */ { ACT_DANGER,  ACT_WARNING, ACT_IDLE   },
};

/* ===== VARIABEL GLOBAL ===== */
uint16_t adc_buf[16];
uint8_t  win_size      = WIN_MAX;
uint16_t prev_sample   = 0;
uint8_t  sys_mode      = 0;              /* 0 = AUTO */
volatile uint8_t crit_flag = 0;
char     uart_out[100];
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
void PeriphCommonClock_Config(void);
void MX_USB_HOST_Process(void);

/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
/* ============================================================
 * WVAF — Variable-Window Adaptive Filter
 * ============================================================ */
void shift_buf(uint16_t *b, uint16_t val, uint8_t n) {
    for (int i = n-1; i > 0; i--) b[i] = b[i-1];
    b[0] = val;
}

uint16_t avg_buf(uint16_t *b, uint8_t n) {
    uint32_t s = 0;
    for (int i = 0; i < n; i++) s += b[i];
    return (uint16_t)(s / n);
}

uint16_t WVAF_Filter(uint16_t sample) {
    uint16_t delta = (sample > prev_sample) ?
                     (sample - prev_sample) : (prev_sample - sample);
    prev_sample = sample;
    win_size = (delta > DELTA_THRESH) ? WIN_MIN : WIN_MAX;
    shift_buf(adc_buf, sample, win_size);
    return avg_buf(adc_buf, win_size);
}

/* ============================================================
 * Evaluasi State Sensor berdasarkan Suhu LM35
 * T(°C) = ADC * 330 / 4096
 * NORMAL  : T < 30°C  → ADC < 372  (30*4096/330 ≈ 372)
 * WARNING : T < 40°C  → ADC < 496  (40*4096/330 ≈ 496)
 * DANGER  : T >= 40°C → ADC >= 496
 * ============================================================ */
uint8_t get_state(uint16_t val) {
    if (val < 372)       return STATE_NORMAL;
    else if (val < 496)  return STATE_WARNING;
    else                 return STATE_DANGER;
}

/* ============================================================
 * Kontrol Aktuator
 * PB0 = LED RED | PB1 = LED GREEN | PB8 = RELAY (via Q1)
 * ============================================================ */
void actuator_set(uint8_t cmd) {
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_1, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_RESET);
    switch (cmd) {
        case ACT_NORMAL:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_1, GPIO_PIN_SET);  /* GREEN ON */
            break;
        case ACT_WARNING:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);  /* RED ON */
            break;
        case ACT_DANGER:
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0, GPIO_PIN_SET);  /* RED ON */
            HAL_GPIO_WritePin(GPIOB, GPIO_PIN_8, GPIO_PIN_SET);  /* RELAY ON */
            break;
        case ACT_IDLE:
        default:
            break;
    }
}
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* Configure the peripherals common clocks */
  PeriphCommonClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_ADC1_Init();
  /* MX_I2C1_Init();  -- tidak dipakai DMCM-WVAF */
  /* MX_I2S2_Init();  -- BUTUH PLLI2S, dinonaktifkan (Proteus-safe) */
  /* MX_I2S3_Init();  -- BUTUH PLLI2S, dinonaktifkan (Proteus-safe) */
  /* MX_SPI1_Init();  -- tidak dipakai DMCM-WVAF */
  MX_TIM2_Init();
  MX_USART1_UART_Init();
  /* MX_USB_HOST_Init(); -- tidak dipakai DMCM-WVAF */
  /* USER CODE BEGIN 2 */
  /* Inisialisasi buffer WVAF */
  memset(adc_buf, 0, sizeof(adc_buf));

  /* Start SBTP Timer — Zona Kritis 5ms */
  HAL_TIM_Base_Start_IT(&htim2);

  /* Pesan startup ke Virtual Terminal */
  const char *hello =
    "\r\n===  DMCM-WVAF + LM35 | STM32F401C-DISCO  ===\r\n"
    "  SENSOR : LM35 VOUT -> PA1 (ADC1_IN1)\r\n"
    "  WIRING : +V8->3.3V  VOUT->PA1  GND->GND\r\n"
    "  OUTPUT : PB0=LED_RED   PB1=LED_GREEN   PB8=RELAY\r\n"
    "  STATE  : NORMAL:<30C  WARNING:30-39C  DANGER:>=40C\r\n"
    "====================================================\r\n";
  HAL_UART_Transmit(&huart1, (uint8_t*)hello, strlen(hello), 200);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */
    /* MX_USB_HOST_Process(); -- USB Host tidak dipakai */

    /* USER CODE BEGIN 3 */
    /* ========== ZONA NON-KRITIS ==========
     * Jika bagian ini hang, Zona Kritis (TIM2 IRQ) tetap berjalan aman.
     * Tambahkan tugas non-kritis di sini: logging, display, dsb. */
    HAL_Delay(50);
    crit_flag = 0;
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE2);

  /**
   * HSI ONLY — Tanpa PLL (Proteus-safe)
   * PLL tidak disimulasikan Proteus dengan benar → MCU akan hang jika PLL aktif
   * SYSCLK = HSI = 16 MHz
   */
  RCC_OscInitStruct.OscillatorType      = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState            = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState        = RCC_PLL_NONE;  /* PLL DISABLED */
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** SYSCLK = HSI = 16 MHz, APB1 = /1 = 16 MHz, APB2 = /1 = 16 MHz */
  RCC_ClkInitStruct.ClockType      = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
                                   | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource   = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider  = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;   /* APB1 = 16 MHz */
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;   /* APB2 = 16 MHz */

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief Peripherals Common Clock Configuration
  * @retval None
  */
void PeriphCommonClock_Config(void)
{
  /**
   * BYPASSED: PLLI2S membutuhkan PLL aktif.
   * PLL tidak digunakan (Proteus-safe), dan I2S tidak dipakai
   * dalam project DMCM-WVAF, sehingga fungsi ini dikosongkan.
   */
  return;
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
  * @brief  Period elapsed callback in non blocking mode
  * @note   This function is called  when TIM1 interrupt took place, inside
  * HAL_TIM_IRQHandler(). It makes a direct call to HAL_IncTick() to increment
  * a global variable "uwTick" used as application time base.
  * @param  htim : TIM handle
  * @retval None
  */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
  /* USER CODE BEGIN Callback 0 */

  /* USER CODE END Callback 0 */
  if (htim->Instance == TIM1)
  {
    HAL_IncTick();
  }
  /* USER CODE BEGIN Callback 1 */
  if (htim->Instance == TIM2)
  {
    crit_flag = 1;

    /* ========== ZONA KRITIS: SBTP (5ms) ========== */

    /* 1. Baca ADC Channel 1 (PA1 — sensor LM35) */
    ADC_ChannelConfTypeDef ch = {0};
    ch.Channel      = ADC_CHANNEL_1;          /* PA1 → LM35 VOUT */
    ch.Rank         = 1;
    ch.SamplingTime = ADC_SAMPLETIME_56CYCLES;
    HAL_ADC_ConfigChannel(&hadc1, &ch);
    HAL_ADC_Start(&hadc1);
    HAL_ADC_PollForConversion(&hadc1, 10);
    uint16_t raw = HAL_ADC_GetValue(&hadc1);
    HAL_ADC_Stop(&hadc1);

    /* 2. WVAF Filter — jendela adaptif */
    uint16_t filtered = WVAF_Filter(raw);

    /* 3. Evaluasi State Sensor */
    uint8_t state = get_state(filtered);

    /* 4. O(1) State Matrix Lookup */
    uint8_t cmd = state_matrix[state][sys_mode];

    /* 5. Eksekusi Aktuator */
    actuator_set(cmd);

    /* 6. Konversi ADC ke suhu LM35 (10mV/°C, Vref=3.3V, 12-bit)
     * T(°C) = (raw * 3300mV) / (4096 * 10mV) = raw * 330 / 4096 */
    uint16_t temp_raw      = (uint16_t)((raw      * 330UL) / 4096UL);
    uint16_t temp_filtered = (uint16_t)((filtered * 330UL) / 4096UL);

    /* 7. Kirim data ke Virtual Terminal (USART1: PA9=TX, PA10=RX) */
    const char* st[] = {"NORMAL ", "WARNING", "DANGER "};
    const char* ac[] = {"Green  ", "Red    ", "Red+RLY", "Idle   "};
    snprintf(uart_out, sizeof(uart_out),
             "[DMCM] T:%2d C  FLT:%2d W:%-2d  ADC:%4d | %s | %s\r\n",
             temp_raw, temp_filtered, win_size, raw, st[state], ac[cmd]);
    HAL_UART_Transmit(&huart1, (uint8_t*)uart_out, strlen(uart_out), 50);
  }
  /* USER CODE END Callback 1 */
}

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
