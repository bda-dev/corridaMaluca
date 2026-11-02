# Rodando no celular Android

O projeto já vem com um preset de exportação Android (`export_presets.cfg`) configurado para:
paisagem com sensor (gira entre as duas orientações deitadas), tela cheia imersiva,
permissão de **vibração**, arm64-v8a + armeabi-v7a e renderizador **Compatibility**
(OpenGL ES 3 — roda até em celulares modestos).

## 1. Instale as ferramentas (uma vez só)

1. **Godot 4.3 ou mais novo** (versão *Standard*, não precisa da .NET): https://godotengine.org/download
2. **OpenJDK 17**: https://adoptium.net (Temurin 17)
3. **Android SDK**: o jeito mais fácil é instalar o **Android Studio** (https://developer.android.com/studio)
   e, no *SDK Manager*, marcar: *Android SDK Platform-Tools*, *Android SDK Build-Tools* e
   *Android SDK Command-line Tools*.
4. No Godot: **Editor → Configurações do Editor → Exportar → Android**
   * `Java SDK Path` → pasta do JDK 17
   * `Android SDK Path` → pasta do SDK (ex.: `C:\Users\voce\AppData\Local\Android\Sdk` ou `~/Android/Sdk`)
   * O *debug keystore* é criado automaticamente pelo Godot 4.3+ (senão, veja o passo 6).
5. No Godot: **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar** (templates da sua versão).

## 2. Teste rápido no celular (sem gerar APK à mão)

1. No celular: **Configurações → Sobre o telefone → toque 7× em "Número da versão"** para liberar
   as *Opções do desenvolvedor*; lá dentro ative **Depuração USB**.
2. Conecte o celular no USB e aceite a autorização de depuração.
3. No Godot aparece um ícone do Android no canto superior direito (**Implantação Remota**):
   clique nele — o jogo é instalado e aberto no celular.

## 3. Gerar o APK

1. **Projeto → Exportar…** → selecione o preset **Android**.
2. Clique em **Exportar Projeto**, escolha `build/android/CorridaMaluca.apk`.
   Desmarque *Exportar com Depuração* para a versão final.
3. Instale com `adb install -r build/android/CorridaMaluca.apk` ou copie o APK para o celular.

## 4. Publicar na Play Store (quando chegar a hora)

* Gere um **keystore de release** (passo 6) e preencha em *Exportar → Android → Keystore → Release*.
* Ative `gradle_build/use_gradle_build` (Projeto → Instalar Modelo de Build Android) e mude
  *Export Format* para **AAB**.
* Aumente `version/code` a cada envio.

## 5. Ajustes de celular já feitos no projeto

| Item | Onde |
|---|---|
| Resolução base 1280×720, `canvas_items` + `expand` (aproveita telas 19,5:9) | `project.godot` |
| Orientação paisagem com sensor | `display/window/handheld/orientation=4` |
| Botão "voltar" do Android pausa/volta em vez de fechar o app | `config/quit_on_go_back=false` + `_notification()` nas cenas |
| Pausa automática ao sair do app | `RaceController._notification(FOCUS_OUT)` |
| Área segura (notch) na HUD | `RaceHUD._safe_margins()` |
| Multi-toque real (acelerar + item ao mesmo tempo) | `TouchInput.gd` |
| Vibração (opcional nas Opções) | `GameManager.vibrate()` + permissão `vibrate` |
| Giroscópio (opcional, com inverter e sensibilidade) | `PlayerController.gd` |
| Texturas ETC2/ASTC | `rendering/textures/vram_compression/import_etc2_astc=true` |

## 6. Problemas comuns

* **"Debug keystore não configurado"**: gere um com
  `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999`
  e aponte em *Configurações do Editor → Exportar → Android → Debug Keystore*.
* **Giroscópio virando ao contrário**: Opções → *Inverter giroscópio* (cada fabricante reporta o eixo de um jeito).
* **Tela preta em celular antigo**: o projeto já usa o renderizador *Compatibility*; confirme em
  *Projeto → Configurações → Renderização → Renderizador* que `Rendering Method.mobile` = `gl_compatibility`.
* **Música demora uns segundos para começar**: sem arquivo de música, o chiptune é sintetizado numa
  thread na primeira vez. Coloque `music_menu.ogg`/`music_race.ogg` em `assets/kenney/audio/` (ou `custom/audio/`) para tocar na hora.
