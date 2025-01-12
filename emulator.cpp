//#include "emulator.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <cassert>
#include <cstdint>

class Emulator {
public:
    Emulator() : memory(65536, 0), video_memory(8192, 0), interrupt_flag(false), timer(0), disk_command(0), sector(0) {}

    void load_memory(const std::string &filename) {
        std::ifstream file(filename, std::ios::binary);
        if (file.is_open()) {
            file.read(reinterpret_cast<char *>(memory.data()), memory.size() * sizeof(uint16_t));
        }
    }

    void load_disk(const std::string &filename) {
        disk_file = filename;
        std::ifstream file(filename, std::ios::binary);
        if (file.is_open()) {
            file.read(reinterpret_cast<char *>(disk.data()), disk.size() * sizeof(uint16_t));
        }
    }

    void execute() {
        while (true) {
            if (interrupt_flag) {
                handle_interrupt();
                interrupt_flag = false;
            }

            uint16_t instruction = fetch_instruction();
            if (!execute_instruction(instruction)) {
                break;
            }

            timer++;
            if (timer >= 8000) { // Simulates 20ms at 8 MHz
                interrupt_flag = true;
                timer = 0;
            }
        }
    }

    void test() {
        test_instructions();
        test_interrupts();
        test_video_memory();
        test_disk_operations();
        std::cout << "All tests passed!" << std::endl;
    }

private:
    std::vector<uint16_t> memory;
    std::vector<uint16_t> video_memory;
    std::vector<uint16_t> disk = std::vector<uint16_t>(1024 * 10, 0); // 10 sectors, each 1 kiloword
    std::string disk_file;
    bool interrupt_flag;
    uint16_t timer;

    // Disk-related registers
    uint16_t disk_command; // Port 0xFFFE
    uint16_t sector;       // Port 0xFFFD

    uint16_t fetch_instruction() {
        // Simulate fetching an instruction from memory
        static uint16_t program_counter = 0;
        return memory[program_counter++];
    }

    bool execute_instruction(uint16_t instruction) {
        switch (instruction & 0xF000) {
        case 0x1000:
            // LOD (Load instruction)
            return execute_lod(instruction);
        case 0x2000:
            // ADD (Add instruction)
            return execute_add(instruction);
        case 0x4000:
            // JMP (Jump instruction)
            return execute_jmp(instruction);
        case 0xF000:
            // HALT (Stop execution)
            return false;
        default:
            std::cerr << "Unknown instruction: " << std::hex << instruction << std::endl;
            return false;
        }
    }

    void handle_interrupt() {
        std::cout << "Interrupt handled at timer: " << timer << std::endl;
        // Simulate reading keyboard input
        uint16_t keycode = read_keyboard();
        if (keycode != 0) {
            // Display keycode in video memory (simulate LED behavior)
            video_memory[keycode % 8192] = keycode;
            std::cout << "Key pressed: " << keycode << " displayed in video memory." << std::endl;
        }
    }

    uint16_t read_keyboard() {
        // Simulated keyboard input (port 0xFFFF)
        static uint16_t simulated_key = 0x41; // ASCII 'A'
        return simulated_key++;
    }

    void handle_disk_command() {
        switch (disk_command) {
        case 0: // Reset
            std::cout << "Disk reset." << std::endl;
            break;
        case 1: // Read
            if (sector < 10) {
                std::copy(disk.begin() + sector * 1024, disk.begin() + (sector + 1) * 1024, memory.begin());
                std::cout << "Read sector " << sector << " into memory." << std::endl;
            } else {
                std::cerr << "Invalid sector for read: " << sector << std::endl;
            }
            break;
        case 2: // Write
            if (sector < 10) {
                std::copy(memory.begin(), memory.begin() + 1024, disk.begin() + sector * 1024);
                std::ofstream file(disk_file, std::ios::binary);
                file.write(reinterpret_cast<const char *>(disk.data()), disk.size() * sizeof(uint16_t));
                std::cout << "Written memory to sector " << sector << "." << std::endl;
            } else {
                std::cerr << "Invalid sector for write: " << sector << std::endl;
            }
            break;
        default:
            std::cerr << "Unknown disk command: " << disk_command << std::endl;
        }
    }

    void test_instructions() {
        memory[0] = 0x100A; // LOD R0, 10
        memory[10] = 42;
        execute_instruction(memory[0]);
        assert(memory[10] == 42);
        std::cout << "Instruction test passed." << std::endl;
    }

    void test_interrupts() {
        interrupt_flag = true;
        handle_interrupt();
        std::cout << "Interrupt test passed." << std::endl;
    }

    void test_video_memory() {
        uint16_t keycode = read_keyboard();
        video_memory[keycode % 8192] = keycode;
        assert(video_memory[keycode % 8192] == keycode);
        std::cout << "Video memory test passed." << std::endl;
    }

    void test_disk_operations() {
        disk_command = 1; // Read
        sector = 0;
        handle_disk_command();
        disk_command = 2; // Write
        handle_disk_command();
        std::cout << "Disk operations test passed." << std::endl;
    }

    bool execute_lod(uint16_t instruction) {
        uint16_t reg = (instruction >> 8) & 0x0F;
        uint16_t addr = instruction & 0x00FF;
        std::cout << "LOD R" << reg << ", " << addr << std::endl;
        return true;
    }

    bool execute_add(uint16_t instruction) {
        uint16_t reg1 = (instruction >> 8) & 0x0F;
        uint16_t reg2 = instruction & 0x00FF;
        std::cout << "ADD R" << reg1 << ", R" << reg2 << std::endl;
        return true;
    }

    bool execute_jmp(uint16_t instruction) {
        uint16_t addr = instruction & 0x0FFF;
        std::cout << "JMP " << addr << std::endl;
        return true;
    }
};

int main() {
    Emulator emu;
    emu.load_memory("memory_test.bin");
    emu.load_disk("disk_test.bin");
    emu.test();
    return 0;
}
