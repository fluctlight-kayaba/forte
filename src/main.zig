const std = @import("std");
const SDL = @import("sdl2");

pub fn main() !void {
    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) sdlPanic();
    defer SDL.SDL_Quit();

    var window = SDL.SDL_CreateWindow(
        "Forte Bassh",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        640,
        480,
        SDL.SDL_WINDOW_SHOWN,
    );
    defer SDL.SDL_DestroyWindow(window);

    var renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer SDL.SDL_DestroyRenderer(renderer);

    mainLoop: while (true) {
        var ev: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&ev) != 0) {
            if (ev.type == SDL.SDL_QUIT) break :mainLoop;
        }

        _ = SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
        _ = SDL.SDL_RenderClear(renderer);
        SDL.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
