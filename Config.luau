--!strict
-- Config.lua

-- [[ DEFINIÇÃO DOS TIPOS ]] --

type UIConfig = {
	DefaultFadeTime: number,             -- Quanto tempo leva pro menu aparecer/sumir
	DefaultTweenTime: number,            -- Velocidade padrão de qualquer animação (ex: botão aumentando)
	DefaultTweenStyle: Enum.EasingStyle, -- O "ritmo" da animação (suave, elástico, etc)
	DefaultTweenDirection: Enum.EasingDirection,
	OverlayFadeTime: number,             -- Velocidade das sombras e fundos pretos atrás das janelas
	TooltipDelay: number,                -- Quanto tempo o mouse tem que ficar parado pra mostrar a dica
	ModalBackgroundTransparency: number, -- O quão escuro fica o fundo quando uma janela abre
	MaxOpenFrames: number,               -- Quantas janelas podem ficar abertas ao mesmo tempo
}

type TextConfig = {
	DefaultTypingSpeed: number,          -- Velocidade do efeito de "máquina de escrever" nos textos
	FadeTime: number,                    -- Tempo pro texto sumir suavemente
}

type InputConfig = {
	EnableKeyboardShortcuts: boolean,    -- Se as teclas de atalho (E, I, M) estão ativadas
	DefaultClickDelay: number,           -- Trava de segurança: evita que o player clique igual um maluco
}

type DebugConfig = {
	ShowUIBorders: boolean,              -- Ajuda no design: coloca bordas pra ver o tamanho real das caixas
	EnableLogs: boolean,                 -- Ativa as mensagens de aviso no console
	VerboseTweens: boolean,              -- Log detalhado: avisa toda vez que uma animação começa/termina
}

export type ConfigType = {
	UI: UIConfig,
	Text: TextConfig,
	Input: InputConfig,
	Debug: DebugConfig,
}

-- [[ CONFIGURAÇÕES REAIS ]] --

local Config: ConfigType = {}

-- Ajustes de Interface
Config.UI = {
	DefaultFadeTime = 0.5,
	DefaultTweenTime = 0.5,
	DefaultTweenStyle = Enum.EasingStyle.Quad,
	DefaultTweenDirection = Enum.EasingDirection.Out,
	OverlayFadeTime = 0.3,
	TooltipDelay = 0.7,
	ModalBackgroundTransparency = 0.5,
	MaxOpenFrames = 1, -- Configurado para fechar uma janela se o player abrir outra
}

-- Ajustes de Escrita e Legendas
Config.Text = {
	DefaultTypingSpeed = 0.05,
	FadeTime = 0.3,
}

-- Controles e Cliques
Config.Input = {
	EnableKeyboardShortcuts = true,
	DefaultClickDelay = 0.2, -- 200ms de intervalo para evitar cliques duplos por erro
}

-- Ferramentas de Desenvolvedor (Mude para 'false' antes de lançar o jogo)
Config.Debug = {
	ShowUIBorders = false,
	EnableLogs = true,
	VerboseTweens = false,
}

return Config
