import type { Config } from 'tailwindcss';
import { fontFamily } from 'tailwindcss/defaultTheme';

const config: Config = {
	darkMode: ['class'],
	content: ['./src/**/*.{html,js,svelte,ts}'],
	safelist: ['dark'],
	theme: {
		container: {
			center: true,
			padding: '2rem',
			screens: {
				'2xl': '1400px'
			}
		},
		extend: {
			colors: {
				border: 'hsl(var(--border) / <alpha-value>)',
				input: 'hsl(var(--input) / <alpha-value>)',
				ring: 'hsl(var(--ring) / <alpha-value>)',
				background: 'hsl(var(--background) / <alpha-value>)',
				foreground: 'hsl(var(--foreground) / <alpha-value>)',
				primary: {
					DEFAULT: 'hsl(var(--primary) / <alpha-value>)',
					foreground: 'hsl(var(--primary-foreground) / <alpha-value>)'
				},
				secondary: {
					DEFAULT: 'hsl(var(--secondary) / <alpha-value>)',
					foreground: 'hsl(var(--secondary-foreground) / <alpha-value>)'
				},
				destructive: {
					DEFAULT: 'hsl(var(--destructive) / <alpha-value>)',
					foreground: 'hsl(var(--destructive-foreground) / <alpha-value>)'
				},
				muted: {
					DEFAULT: 'hsl(var(--muted) / <alpha-value>)',
					foreground: 'hsl(var(--muted-foreground) / <alpha-value>)'
				},
				accent: {
					DEFAULT: 'hsl(var(--accent) / <alpha-value>)',
					foreground: 'hsl(var(--accent-foreground) / <alpha-value>)'
				},
				popover: {
					DEFAULT: 'hsl(var(--popover) / <alpha-value>)',
					foreground: 'hsl(var(--popover-foreground) / <alpha-value>)'
				},
				card: {
					DEFAULT: 'hsl(var(--card) / <alpha-value>)',
					foreground: 'hsl(var(--card-foreground) / <alpha-value>)'
				}
			},
			borderRadius: {
				lg: 'var(--radius)',
				md: 'calc(var(--radius) - 2px)',
				sm: 'calc(var(--radius) - 4px)'
			},
			fontFamily: {
				sans: [...fontFamily.sans]
			},
			animation: {
				'bounce-right': 'bounce-right 1.5s ease-in-out infinite',
				heartbeat: 'heartbeat 1.5s linear infinite'
			},
			keyframes: {
				'bounce-right': {
					'0%, 100%': {
						transform: 'translateX(15%)'
					},
					'50%': {
						transform: 'translateX(0)'
					}
				},
				heartbeat: {
					'0%': {
						transform: 'scale(.75)',
						filter: 'brightness(.95) blur(0)'
					},
					'10%': {
						filter: 'blur(4px)'
					},
					'20%': {
						transform: 'scale(1)',
						filter: 'brightness(1) blur(0)'
					},
					'30%': {
						filter: 'blur(4px)'
					},
					'40%': {
						transform: 'scale(.75)',
						filter: 'brightness(.95) blur(0)'
					},
					'50%': {
						filter: 'blur(4px)'
					},
					'60%': {
						transform: 'scale(1)',
						filtern: 'brightness(1) blur(0)'
					},
					'70%': {
						filter: 'blur(4px)'
					},
					'80%': {
						transform: 'scale(.75)',
						filter: 'brightness(.95) blur(0)'
					},
					'90%': {
						filter: 'blur(0)'
					},
					'100%': {
						transform: 'scale(.75)',
						filter: 'brightness(.95) blur(0)'
					}
				}
			}
		}
	}
};

export default config;
