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
        if (!initialize_visualization())
        {
            std::cerr << "Failed to initialize SDL visualization.\n";
            return;
        }

        initialize_video_memory();
        test_program();

        while (true)
        {
            handle_keyboard_input();
            handle_io_ports();

            if (interrupt_flag)
            {
                handle_interrupt();
                interrupt_flag = false;
            }

            uint16_t instruction = fetch_instruction();
            if (!execute_instruction(instruction))
            {
                break;
            }

            timer++;
            if (timer >= 8000)
            {
                interrupt_flag = true;
                timer = 0;
            }

            draw_screen();
            SDL_Delay(16);
        }

        cleanup_visualization();
    }

    void test_all()
    {
        std::cout << "Running all tests...\n";

        initialize_video_memory();
        std::cout << "[Test] Video memory initialized.\n";

        load_ascii_table();
        std::cout << "[Test] ASCII table loaded.\n";

        execute_test_disk_operations();
        std::cout << "[Test] Disk operations completed.\n";

        test_sequence();
        std::cout << "[Test] Sequence test completed.\n";

        std::cout << "All tests completed successfully.\n";
    }

    void initialize_rom()
    {
        for (uint16_t i = 0; i < 1024; ++i)
        {
            memory[i] = 0x0000; // Inicijalizacija ROM-a sa NOP instrukcijama
        }

        // Primjer osnovnog boot loadera
        memory[0] = 0x1000; // LOD instrukcija
        memory[1] = 0x2001; // ADD instrukcija
        memory[2] = 0x4000; // JMP instrukcija
        std::cout << "Boot loader initialized in ROM.\n";
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

    // SDL2-related members
    SDL_Window *window = nullptr;
    SDL_Renderer *renderer = nullptr;
    SDL_Event event;

    void initialize_video_memory()
    {
        // Početni simbol u video memoriji
        video_memory[0] = 0x0005; // Aktivira segmente 0 i 2
        load_fonts();
        std::cout << "Video memory initialized." << std::endl;
    }

    void load_ascii_table()
    {
        for (uint16_t i = 0; i < 128; ++i)
        {
            video_memory[i] = i; // Simuliraj ASCII prikaz (ili koristi predefinisan izgled znakova)
        }
        std::cout << "ASCII table loaded into video memory.\n";
    }

    void test_program()
    {
        // Simulacija promene simbola u memoriji
        video_memory[0] = 0x0003; // Aktivira segmente 0 i 1
        std::cout << "Test program initialized video memory.\n";
    }

    void execute_test_disk_operations()
    {
        // Test reset diska
        disk_command = 0; // Reset
        handle_io_ports();

        // Test čitanja sa diska
        disk_command = 1; // Čitanje
        sector = 0;
        handle_io_ports();

        // Test pisanja na disk
        disk_command = 2; // Pisanje
        handle_io_ports();
    }

    void test_sequence()
    {
        for (uint16_t i = 0; i < 25; ++i)
        {
            for (uint16_t j = 0; j < 80; ++j)
            {
                video_memory[i * 80 + j] = 1 << (i % 16); // Aktiviraj samo jedan segment
                draw_screen();
                SDL_Delay(100); // Pauza da se vidi promena
            }
        }
        std::cout << "Sequence test completed.\n";
    }

    void handle_io_ports()
    {
        // 0xFFFE - Disk komanda (čitamo ili pišemo sa diska ili resetujemo)
        switch (disk_command)
        {
        case 0: // Reset
            reset_disk();
            std::cout << "Disk reset executed." << std::endl;
            break;
        case 1: // Read
            if (sector < disk.size() / 256)
            { // Provjera validnog sektora
                std::ifstream disk_stream(disk_file, std::ios::binary);
                if (disk_stream.is_open())
                {
                    disk_stream.seekg(sector * 256 * sizeof(uint16_t));
                    disk_stream.read(reinterpret_cast<char *>(memory.data()), 256 * sizeof(uint16_t));
                    if (disk_stream.gcount() == 256 * sizeof(uint16_t))
                    {
                        std::cout << "Sector " << sector << " read successfully.\n";
                    }
                    else
                    {
                        std::cerr << "Error reading sector " << sector << ".\n";
                    }
                }
            }
            else
            {
                std::cerr << "Invalid sector for read: " << sector << std::endl;
            }
            break;
        case 2: // Write
            if (sector < disk.size() / 256)
            { // Provjera validnog sektora
                std::ofstream disk_stream(disk_file, std::ios::binary | std::ios::in);
                if (disk_stream.is_open())
                {
                    disk_stream.seekp(sector * 256 * sizeof(uint16_t));
                    disk_stream.write(reinterpret_cast<char *>(memory.data()), 256 * sizeof(uint16_t));
                    std::cout << "Memory written to sector " << sector << "." << std::endl;
                }
            }
            else
            {
                std::cerr << "Invalid sector for write: " << sector << std::endl;
            }
            break;
        default:
            std::cerr << "Unknown disk command: " << disk_command << std::endl;
        }
    }

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
                uint8_t scan_code = static_cast<uint8_t>(event.key.keysym.sym);
                uint8_t ascii_code = scan_code_to_ascii(scan_code); // Koristi scan_code_to_ascii
                if (ascii_code != 0)
                {                                      // Provjerava validan ASCII kod
                    video_memory[0] = ascii_code;      // Prikaz na prvoj poziciji video memorije
                    video_memory[1] = ascii_code << 1; // Test promjene (ili simulacija)
                    draw_screen();                     // Ažuriranje ekrana
                    std::cout << "Key pressed: " << SDL_GetKeyName(event.key.keysym.sym)
                              << " (ASCII: " << ascii_code << ")" << std::endl;
                }
            }
        }
    }

    void handle_interrupt()
    {
        std::cout << "Timer interrupt!" << std::endl;
        draw_screen(); // Osvježavanje ekrana
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

    bool initialize_visualization()
    {
        if (SDL_Init(SDL_INIT_VIDEO) < 0)
        {
            std::cerr << "SDL could not initialize: " << SDL_GetError() << std::endl;
            return false;
        }
        window = SDL_CreateWindow("Emulator", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 800, 600, SDL_WINDOW_SHOWN);
        if (!window)
        {
            std::cerr << "Window could not be created: " << SDL_GetError() << std::endl;
            return false;
        }
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
        if (!renderer)
        {
            std::cerr << "Renderer could not be created: " << SDL_GetError() << std::endl;
            return false;
        }
        return true;
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
                // Koordinate početne pozicije znaka
                int x = col * 20; // širina znaka
                int y = row * 40; // visina znaka

                for (int segment = 0; segment < 16; ++segment)
                {
                    // Odredi poziciju i dimenzije LED segmenta
                    SDL_Rect segment_rect;
                    switch (segment)
                    {
                    case 0:
                        segment_rect = {x + 4, y, 12, 2};
                        break; // Gornji horizontalni
                    case 1:
                        segment_rect = {x + 16, y + 2, 2, 12};
                        break; // Gornji desni vertikalni
                    case 2:
                        segment_rect = {x + 16, y + 20, 2, 12};
                        break; // Donji desni vertikalni
                    case 3:
                        segment_rect = {x + 4, y + 32, 12, 2};
                        break; // Donji horizontalni
                    case 4:
                        segment_rect = {x, y + 20, 2, 12};
                        break; // Donji levi vertikalni
                    case 5:
                        segment_rect = {x, y + 2, 2, 12};
                        break; // Gornji levi vertikalni
                    case 6:
                        segment_rect = {x + 4, y + 16, 12, 2};
                        break; // Srednji horizontalni
                    // Dodatni segmenti za 16-segmentni prikaz
                    case 7:
                        segment_rect = {x + 2, y + 2, 2, 12};
                        break; // Dijagonalni levi gornji
                    case 8:
                        segment_rect = {x + 14, y + 2, 2, 12};
                        break; // Dijagonalni desni gornji
                    case 9:
                        segment_rect = {x + 2, y + 20, 2, 12};
                        break; // Dijagonalni levi donji
                    case 10:
                        segment_rect = {x + 14, y + 20, 2, 12};
                        break; // Dijagonalni desni donji
                    case 11:
                        segment_rect = {x + 6, y + 6, 8, 2};
                        break; // Horizontalni srednji gornji
                    case 12:
                        segment_rect = {x + 6, y + 28, 8, 2};
                        break; // Horizontalni srednji donji
                    case 13:
                        segment_rect = {x + 2, y + 14, 2, 12};
                        break; // Vertikalni levi srednji
                    case 14:
                        segment_rect = {x + 16, y + 14, 2, 12};
                        break; // Vertikalni desni srednji
                    case 15:
                        segment_rect = {x + 6, y + 14, 8, 2};
                        break; // Horizontalni centralni
                    }

                    if (word & (1 << segment))
                    {
                        SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255); // Aktivni segment
                    }
                    else
                    {
                        SDL_SetRenderDrawColor(renderer, 50, 50, 50, 255); // Neaktivni segment
                    }
                    SDL_RenderFillRect(renderer, &segment_rect);
                }
            }
        }
        SDL_RenderPresent(renderer);
    }

    bool execute_lod(uint16_t instruction)
    {
        uint16_t reg = (instruction >> 8) & 0x0F; // Registar u koji se učitava
        uint16_t addr = instruction & 0x00FF;     // Adresa iz koje se učitava

        if (addr < 1024)
        { // ROM je zaštićen
            std::cerr << "Error: Attempt to write to ROM address " << addr << std::endl;
            return false;
        }

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

    // Funkcija za resetovanje diska
    void reset_disk()
    {
        sector = 0;                      // Postavljanje sektora na početni
        disk_command = 0;                // Poništavanje komande
        memory.assign(memory.size(), 0); // Resetovanje memorije
        std::cout << "Disk and memory reset completed." << std::endl;
    }

    uint8_t scan_code_to_ascii(uint8_t scan_code)
    {
        // Provjeravamo da li sken kod postoji u mapi
        auto it = key_map.find(scan_code);
        if (it != key_map.end())
        {
            return it->second; // Vraćamo odgovarajući ASCII kod
        }
        return 0; // Nevažeći sken kod
    }

    void load_fonts()
    {
        // Primjer: predefinisani fontovi za par simbola
        video_memory[0] = 0x1FFF; // Svi segmenti aktivni za prvi simbol
        video_memory[1] = 0x0F0F; // Alternativni simbol
        std::cout << "Fonts loaded into video memory.\n";
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
    std::cout << "Emulator Program\n";

    if (argc < 2)
    {
        std::cerr << "Usage: " << argv[0] << " <command> [options]\n";
        std::cerr << "Commands:\n";
        std::cerr << "  generate   Generate test files\n";
        std::cerr << "  run        Run the emulator\n";
        std::cerr << "  test       Run all tests\n";
        return 1;
    }

    std::string command = argv[1];
    Emulator emulator;

    if (command == "generate")
    {
        generate_test_files();
    }
    else if (command == "run")
    {
        emulator.initialize_rom();
        emulator.load_memory("program.bin");
        emulator.load_disk("test_disk.bin");
        emulator.execute();
    }
    else if (command == "test")
    {
        emulator.initialize_rom();
        emulator.test_all();
    }
    else
    {
        std::cerr << "Unknown command: " << command << "\n";
        std::cerr << "Use 'generate', 'run', or 'test'.\n";
        return 1;
    }

    return 0;
}
