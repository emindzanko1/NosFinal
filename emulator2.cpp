#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <cassert>
#include <cstdint>
#include <unordered_map>
#include <chrono>
#include <thread>

// Globalna mapa koja mapira tastere sa ASCII vrednostima
std::unordered_map<SDL_Keycode, uint8_t> key_map = {
    {SDLK_a, 0x61}, {SDLK_b, 0x62}, {SDLK_c, 0x63}, {SDLK_d, 0x64}, {SDLK_e, 0x65}, {SDLK_f, 0x66}, {SDLK_g, 0x67}, {SDLK_h, 0x68}, {SDLK_i, 0x69}, {SDLK_j, 0x6A}, {SDLK_k, 0x6B}, {SDLK_l, 0x6C}, {SDLK_m, 0x6D}, {SDLK_n, 0x6E}, {SDLK_o, 0x6F}, {SDLK_p, 0x70}, {SDLK_q, 0x71}, {SDLK_r, 0x72}, {SDLK_s, 0x73}, {SDLK_t, 0x74}, {SDLK_u, 0x75}, {SDLK_v, 0x76}, {SDLK_w, 0x77}, {SDLK_x, 0x78}, {SDLK_y, 0x79}, {SDLK_z, 0x7A}, {SDLK_1, 0x31}, {SDLK_2, 0x32}, {SDLK_3, 0x33}, {SDLK_4, 0x34}, {SDLK_5, 0x35}, {SDLK_6, 0x36}, {SDLK_7, 0x37}, {SDLK_8, 0x38}, {SDLK_9, 0x39}, {SDLK_0, 0x30}, {SDLK_RETURN, 0x0D}, {SDLK_SPACE, 0x20}, // Dodati specijalni tasteri
};

// Globalni I/O portovi
uint8_t io_ports[0xFFFF] = {0};

void generate_test_files();

class Emulator
{
public:
    Emulator() : memory(65536, 0), video_memory(8192, 0), interrupt_flag(false), timer(0), disk_command(0), sector(0), program_counter(0) {}

    void load_memory(const std::string &filename)
    {
        std::ifstream file(filename, std::ios::binary);
        if (file.is_open())
        {
            file.read(reinterpret_cast<char *>(memory.data()), memory.size() * sizeof(uint16_t));
            std::cout << "Loaded memory from file: " << filename << std::endl;

            // Ispisujemo nekoliko prvih instrukcija da provjerimo
            for (int i = 0; i < 10; ++i)
            {
                std::cout << std::hex << memory[i] << " ";
            }
            std::cout << std::endl;
        }
        else
        {
            std::cerr << "Failed to load memory from file: " << filename << std::endl;
        }
    }

    void load_disk(const std::string &filename)
    {
        disk_file = filename;
        std::ifstream file(filename, std::ios::binary);
        if (file.is_open())
        {
            file.read(reinterpret_cast<char *>(disk.data()), disk.size() * sizeof(uint16_t));
        }
    }

    void execute()
    {
        initialize_visualization();

        while (true)
        {
            handle_keyboard_input(); // Pozvana funkcija
            handle_io_ports();

            if (interrupt_flag)
            {
                handle_interrupt(); // Pozvana funkcija
                interrupt_flag = false;
            }

            uint16_t instruction = fetch_instruction();
            if (!execute_instruction(instruction))
            {
                break;
            }

            timer++;
            if (timer >= 8000)
            { // Simulira 20ms na 8 MHz
                interrupt_flag = true;
                timer = 0;
            }

            draw_screen(); // Ažuriranje vizualizacije u svakom ciklusu
            SDL_Delay(16); // Ograniči na 60 FPS
            // std::this_thread::sleep_for(std::chrono::milliseconds(16)); // Approx 60 FPS
        }

        cleanup_visualization();
    }

private:
    std::vector<uint16_t> memory;
    std::vector<uint16_t> video_memory;
    std::vector<uint16_t> disk = std::vector<uint16_t>(1024 * 10, 0); // 10 sektora, svaki 1 kiloword
    std::vector<uint16_t> registers = std::vector<uint16_t>(16, 0);   // Registri za operacije
    std::string disk_file;
    bool interrupt_flag;
    uint16_t timer;
    uint16_t program_counter; // Dodan programski brojač kao članska promenljiva

    // Disk-related registers
    uint16_t disk_command; // Port 0xFFFE
    uint16_t sector;       // Port 0xFFFD

    uint16_t keyboard_input;

    // SDL2-related members
    SDL_Window *window = nullptr;
    SDL_Renderer *renderer = nullptr;
    SDL_Event event;

    // Dodane funkcije koje su nedostajale

    // void handle_keyboard_input()
    // {
    //     // Ovdje možeš dodati logiku za rukovanje unosom s tastature
    // }

    // void handle_interrupt()
    // {
    //     // Ovdje možeš dodati logiku za rukovanje prekidima
    // }

    // void draw_keyboard()
    // {
    //     // Ovdje možeš dodati kod za crtanje tastature ako je potrebno
    // }

    void handle_keyboard_input()
    {
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_QUIT)
            {
                exit(0);
            }
            else if (event.type == SDL_KEYDOWN)
            {
                // Povezivanje pritisnutih tastera sa portom 0xFFFF
                if (key_map.find(event.key.keysym.sym) != key_map.end())
                {
                    io_ports[0xFFFF] = key_map[event.key.keysym.sym];
                    std::cout << "Key pressed: " << SDL_GetKeyName(event.key.keysym.sym)
                              << " (Port 0xFFFF value: " << std::hex << (int)io_ports[0xFFFF] << std::dec << ")" << std::endl;
                }
            }
        }
    }

    void handle_interrupt()
    {
        std::cout << "Interrupt handled!" << std::endl;
    }

    void start_timer()
    {
        while (true)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            handle_interrupt();
        }
    }

    void draw_keyboard()
    {
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        for (int i = 0; i < 16; ++i)
        {
            SDL_Rect key_rect = {50 + i * 40, 500, 30, 30};
            SDL_RenderFillRect(renderer, &key_rect);
        }
    }

    void initialize_visualization()
    {
        SDL_Init(SDL_INIT_VIDEO);
        window = SDL_CreateWindow("Emulator Screen", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 800, 600, SDL_WINDOW_SHOWN);
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    }

    void cleanup_visualization()
    {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }

    void draw_screen()
    {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);

        for (int row = 0; row < 25; ++row)
        {
            for (int col = 0; col < 80; ++col)
            {
                uint16_t word = video_memory[row * 80 + col];

                for (int segment = 0; segment < 16; ++segment)
                {
                    SDL_Rect rect = {col * 10 + (segment % 4) * 2, row * 20 + (segment / 4) * 4, 2, 4};
                    if (word & (1 << segment))
                    {
                        SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255); // Aktivna LED
                    }
                    else
                    {
                        SDL_SetRenderDrawColor(renderer, 50, 50, 50, 255); // Neaktivna LED
                    }
                    SDL_RenderFillRect(renderer, &rect);
                }
            }
        }

        draw_keyboard(); // Pozvana funkcija

        SDL_RenderPresent(renderer);
    }

    uint16_t fetch_instruction()
    {
        uint16_t instruction = memory[program_counter++];
        std::cout << "PC: " << std::hex << program_counter - 1 << " | Instruction: " << instruction << std::endl;
        return instruction;
    }

    bool execute_instruction(uint16_t instruction)
    {
        switch (instruction & 0xF000)
        {
        case 0x1000:
            return execute_lod(instruction); // Očekuje LOD instrukciju
        case 0x2000:
            return execute_add(instruction); // Očekuje ADD instrukciju
        case 0x4000:
            return execute_jmp(instruction); // Očekuje JMP instrukciju
        case 0xF000:
            return false; // Nema više instrukcija
        default:
            std::cerr << "Unknown instruction: " << std::hex << instruction
                      << " | PC: " << std::hex << program_counter - 1 << std::endl;
            return false;
        }
    }

    bool execute_lod(uint16_t instruction)
    {
        uint16_t reg = (instruction >> 8) & 0x0F; // Registar u koji se učitava
        uint16_t addr = instruction & 0x00FF;     // Adresa iz koje se učitava

        std::cout << "LOD R" << reg << ", " << addr << std::endl;

        registers[reg] = memory[addr];
        return true;
    }

    bool execute_add(uint16_t instruction)
    {
        uint16_t reg1 = (instruction >> 8) & 0x0F; // Registar 1 (od R0 do R15)
        uint16_t reg2 = (instruction >> 4) & 0x0F; // Registar 2 (od R0 do R15)

        // Provjera validnosti registarskih brojeva
        if (reg1 >= 16 || reg2 >= 16)
        {
            std::cerr << "Invalid register in ADD instruction: R" << reg1 << ", R" << reg2 << std::endl;
            return false; // Prekid izvršenja instrukcije
        }

        registers[reg1] += registers[reg2];
        std::cout << "ADD R" << reg1 << ", R" << reg2 << std::endl;
        return true;
    }

    bool execute_jmp(uint16_t instruction)
    {
        uint16_t addr = instruction & 0x0FFF;
        std::cout << "JMP to " << std::hex << addr << std::endl;
        program_counter = addr;
        return true;
    }

    void handle_io_ports()
    {
        // 0xFFFF - Tastatura (prikazivanje pritisnutih tastera)
        if (memory[0xFFFF] != 0)
        {
            keyboard_input = memory[0xFFFF]; // Simulacija tastature
            std::cout << "Keyboard input: " << keyboard_input << std::endl;
        }

        // 0xFFFE - Disk komanda (čitamo ili pišemo sa diska)
        if (memory[0xFFFE] == 1)
        {
            // Komanda za čitanje sa diska
            std::cout << "Read from disk, sector: " << sector << std::endl;
            memory[0xFFFD] = disk[sector]; // Pretpostavljamo da disk sadrži 16-bitne podatke
        }
        else if (memory[0xFFFE] == 2)
        {
            // Komanda za upis na disk
            disk[sector] = memory[0xFFFD];
            std::cout << "Write to disk, sector: " << sector << std::endl;
        }
    }
};

void generate_test_files()
{
    uint16_t program[] = {0x100A, 0x2001, 0xF000};
    std::ofstream file("test_program.bin", std::ios::binary);
    file.write(reinterpret_cast<const char *>(program), sizeof(program));
    file.close();

    std::vector<uint16_t> disk_sector(1024, 0xABCD);
    std::ofstream disk_file("test_disk.bin", std::ios::binary);
    disk_file.write(reinterpret_cast<const char *>(disk_sector.data()), disk_sector.size() * sizeof(uint16_t));
    disk_file.close();

    std::cout << "Test files generated: test_program.bin and test_disk.bin" << std::endl;
}
int main(int argc, char *argv[])
{
    std::cout << "Argumenti: ";
    for (int i = 0; i < argc; ++i)
    {
        std::cout << argv[i] << " ";
    }
    std::cout << std::endl;

    Emulator emulator;

    if (argc > 1 && std::strcmp(argv[1], "generate") == 0)
    {
        generate_test_files();
        return 0; // Dodano: Završava program nakon generisanja fajlova
    }
    else
    {
        emulator.load_memory("program.bin");
        emulator.execute();
    }

    return 0;
}