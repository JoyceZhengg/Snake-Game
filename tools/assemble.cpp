#include <bitset>
#include <cctype>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

struct AsmError : public std::runtime_error {
    using std::runtime_error::runtime_error;
};

struct ParsedLine {
    int lineno;
    std::string original;
    std::string label;
    std::string mnemonic;
    std::vector<std::string> operands;
};

std::string trim(const std::string& text) {
    std::size_t begin = 0;
    while (begin < text.size() && std::isspace(static_cast<unsigned char>(text[begin]))) {
        ++begin;
    }

    std::size_t end = text.size();
    while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1]))) {
        --end;
    }

    return text.substr(begin, end - begin);
}

std::string to_upper(std::string text) {
    for (char& ch : text) {
        ch = static_cast<char>(std::toupper(static_cast<unsigned char>(ch)));
    }
    return text;
}

bool is_ident_start(char ch) {
    return std::isalpha(static_cast<unsigned char>(ch)) || ch == '_';
}

bool is_ident_char(char ch) {
    return std::isalnum(static_cast<unsigned char>(ch)) || ch == '_';
}

bool is_label_name(const std::string& token) {
    if (token.empty() || !is_ident_start(token.front())) {
        return false;
    }
    for (char ch : token) {
        if (!is_ident_char(ch)) {
            return false;
        }
    }
    return true;
}

std::string strip_comment(const std::string& line) {
    std::size_t pos = line.find("//");
    if (pos == std::string::npos) {
        return line;
    }
    return line.substr(0, pos);
}

std::vector<std::string> split_operands(const std::string& text) {
    std::vector<std::string> parts;
    std::stringstream ss(text);
    std::string item;
    while (std::getline(ss, item, ',')) {
        item = trim(item);
        if (!item.empty()) {
            parts.push_back(item);
        }
    }
    return parts;
}

ParsedLine parse_line(int lineno, const std::string& line) {
    ParsedLine parsed{lineno, line, "", "", {}};
    std::string text = trim(strip_comment(line));

    if (text.empty()) {
        return parsed;
    }

    std::size_t colon = text.find(':');
    if (colon != std::string::npos) {
        std::string candidate = trim(text.substr(0, colon));
        if (!is_label_name(candidate)) {
            throw AsmError("line " + std::to_string(lineno) + ": invalid label '" + candidate + "'");
        }
        parsed.label = candidate;
        text = trim(text.substr(colon + 1));
    }

    if (text.empty()) {
        return parsed;
    }

    std::size_t split = 0;
    while (split < text.size() && !std::isspace(static_cast<unsigned char>(text[split]))) {
        ++split;
    }
    parsed.mnemonic = to_upper(text.substr(0, split));
    parsed.operands = split_operands(split < text.size() ? text.substr(split + 1) : "");
    return parsed;
}

int parse_register(const std::string& token, int lineno) {
    if (token.size() != 2 || (token[0] != 'r' && token[0] != 'R') || token[1] < '0' || token[1] > '7') {
        throw AsmError("line " + std::to_string(lineno) + ": expected register, got '" + token + "'");
    }
    return token[1] - '0';
}

int parse_char_literal(const std::string& token, int lineno) {
    if (token.size() < 3 || token.front() != '\'' || token.back() != '\'') {
        throw AsmError("line " + std::to_string(lineno) + ": invalid character literal '" + token + "'");
    }

    std::string body = token.substr(1, token.size() - 2);
    if (body.empty()) {
        throw AsmError("line " + std::to_string(lineno) + ": character literal must decode to one character");
    }

    if (body.size() == 1 && body[0] != '\\') {
        return static_cast<unsigned char>(body[0]);
    }

    if (body[0] != '\\') {
        throw AsmError("line " + std::to_string(lineno) + ": character literal must decode to one character");
    }

    if (body.size() == 2) {
        switch (body[1]) {
            case 'n': return '\n';
            case 'r': return '\r';
            case 't': return '\t';
            case '0': return '\0';
            case '\\': return '\\';
            case '\'': return '\'';
            case '"': return '"';
            default:
                throw AsmError("line " + std::to_string(lineno) + ": unsupported escape in character literal");
        }
    }

    if (body.size() == 4 && body[1] == 'x') {
        int value = std::stoi(body.substr(2), nullptr, 16);
        return value & 0xFF;
    }

    throw AsmError("line " + std::to_string(lineno) + ": character literal must decode to one character");
}

bool starts_with_ci(const std::string& text, const std::string& prefix) {
    if (text.size() < prefix.size()) {
        return false;
    }
    for (std::size_t i = 0; i < prefix.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(text[i])) !=
            std::tolower(static_cast<unsigned char>(prefix[i]))) {
            return false;
        }
    }
    return true;
}

int parse_int_token(const std::string& raw_token, int lineno,
                    const std::unordered_map<std::string, int>& labels) {
    std::string token = trim(raw_token);

    if (token.size() > 6 && token.front() == '<' && token.back() == '>') {
        std::string inner = token.substr(1, token.size() - 2);
        if (inner.size() > 4 && inner.substr(inner.size() - 4) == "_low") {
            std::string label = inner.substr(0, inner.size() - 4);
            auto it = labels.find(label);
            if (it == labels.end()) {
                throw AsmError("line " + std::to_string(lineno) + ": unknown label '" + label + "'");
            }
            return it->second & 0xFF;
        }
        if (inner.size() > 5 && inner.substr(inner.size() - 5) == "_high") {
            std::string label = inner.substr(0, inner.size() - 5);
            auto it = labels.find(label);
            if (it == labels.end()) {
                throw AsmError("line " + std::to_string(lineno) + ": unknown label '" + label + "'");
            }
            return (it->second >> 8) & 0xFF;
        }
    }

    if (starts_with_ci(token, "lo(") && token.back() == ')') {
        std::string label = token.substr(3, token.size() - 4);
        auto it = labels.find(label);
        if (it == labels.end()) {
            throw AsmError("line " + std::to_string(lineno) + ": unknown label '" + label + "'");
        }
        return it->second & 0xFF;
    }

    if (starts_with_ci(token, "hi(") && token.back() == ')') {
        std::string label = token.substr(3, token.size() - 4);
        auto it = labels.find(label);
        if (it == labels.end()) {
            throw AsmError("line " + std::to_string(lineno) + ": unknown label '" + label + "'");
        }
        return (it->second >> 8) & 0xFF;
    }

    if (is_label_name(token)) {
        auto it = labels.find(token);
        if (it != labels.end()) {
            return it->second;
        }
    }

    if (token.size() >= 2 && token.front() == '\'' && token.back() == '\'') {
        return parse_char_literal(token, lineno);
    }

    try {
        std::size_t consumed = 0;
        long value = std::stol(token, &consumed, 0);
        if (consumed != token.size()) {
            throw std::invalid_argument("trailing junk");
        }
        return static_cast<int>(value);
    } catch (const std::exception&) {
        throw AsmError("line " + std::to_string(lineno) + ": invalid immediate '" + token + "'");
    }
}

int require_imm8(const std::string& token, int lineno,
                 const std::unordered_map<std::string, int>& labels) {
    return parse_int_token(token, lineno, labels) & 0xFF;
}

void expect_operands(const ParsedLine& line, std::size_t count, const std::string& usage) {
    if (line.operands.size() != count) {
        throw AsmError("line " + std::to_string(line.lineno) + ": " + line.mnemonic + " expects " + usage);
    }
}

std::uint16_t encode_instruction(const ParsedLine& line,
                                 const std::unordered_map<std::string, int>& labels) {
    const std::string& mnem = line.mnemonic;

    if (mnem == "NOP") {
        expect_operands(line, 0, "no operands");
        return 0x0000;
    }

    if (mnem == "HALT") {
        expect_operands(line, 0, "no operands");
        return 0x07FF;
    }

    if (mnem == "RAND" || mnem == "MOVR") {
        expect_operands(line, 1, "1 operand");
        int rt = parse_register(line.operands[0], line.lineno);
        return static_cast<std::uint16_t>(0x0800 | rt);
    }

    if (mnem == "ADDI") {
        expect_operands(line, 2, "'rT, imm'");
        int rt = parse_register(line.operands[0], line.lineno);
        int imm = require_imm8(line.operands[1], line.lineno, labels);
        return static_cast<std::uint16_t>(0x1000 | (imm << 3) | rt);
    }

    if (mnem == "SUBI") {
        expect_operands(line, 2, "'rT, imm'");
        int rt = parse_register(line.operands[0], line.lineno);
        int imm = require_imm8(line.operands[1], line.lineno, labels);
        return static_cast<std::uint16_t>(0x1800 | (imm << 3) | rt);
    }

    if (mnem == "ADD") {
        expect_operands(line, 3, "'rT, rA, rB'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        int rb = parse_register(line.operands[2], line.lineno);
        return static_cast<std::uint16_t>(0x2000 | (ra << 6) | (rb << 3) | rt);
    }

    if (mnem == "SUB") {
        expect_operands(line, 3, "'rT, rA, rB'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        int rb = parse_register(line.operands[2], line.lineno);
        return static_cast<std::uint16_t>(0x2800 | (ra << 6) | (rb << 3) | rt);
    }

    if (mnem == "MOVL") {
        expect_operands(line, 2, "'rT, imm'");
        int rt = parse_register(line.operands[0], line.lineno);
        int imm = require_imm8(line.operands[1], line.lineno, labels);
        return static_cast<std::uint16_t>(0x3000 | (imm << 3) | rt);
    }

    if (mnem == "MOVH") {
        expect_operands(line, 2, "'rT, imm'");
        int rt = parse_register(line.operands[0], line.lineno);
        int imm = require_imm8(line.operands[1], line.lineno, labels);
        return static_cast<std::uint16_t>(0x3800 | (imm << 3) | rt);
    }

    if (mnem == "BR") {
        expect_operands(line, 1, "'rT'");
        int rt = parse_register(line.operands[0], line.lineno);
        return static_cast<std::uint16_t>(0x4000 | rt);
    }

    if (mnem == "BEQ") {
        expect_operands(line, 3, "'rT, rA, rB'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        int rb = parse_register(line.operands[2], line.lineno);
        return static_cast<std::uint16_t>(0x4800 | (ra << 6) | (rb << 3) | rt);
    }

    if (mnem == "BNE") {
        expect_operands(line, 3, "'rT, rA, rB'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        int rb = parse_register(line.operands[2], line.lineno);
        return static_cast<std::uint16_t>(0x4A00 | (ra << 6) | (rb << 3) | rt);
    }

    if (mnem == "BEQI") {
        expect_operands(line, 3, "'rT, rA, imm'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        int imm = require_imm8(line.operands[2], line.lineno, labels);
        return static_cast<std::uint16_t>(
            0x8000 | ((imm & 0xF8) << 6) | (ra << 6) | ((imm & 0x07) << 3) | rt);
    }

    if (mnem == "STRI") {
        expect_operands(line, 2, "'rA, imm'");
        int ra = parse_register(line.operands[0], line.lineno);
        int imm = require_imm8(line.operands[1], line.lineno, labels);
        return static_cast<std::uint16_t>(0xF000 | (((imm >> 6) & 0x03) << 9) | (ra << 6) | (imm & 0x3F));
    }

    if (mnem == "LDR") {
        expect_operands(line, 2, "'rT, rA'");
        int rt = parse_register(line.operands[0], line.lineno);
        int ra = parse_register(line.operands[1], line.lineno);
        return static_cast<std::uint16_t>(0xF800 | (ra << 6) | rt);
    }

    if (mnem == "STR") {
        expect_operands(line, 2, "'rA, rT'");
        int ra = parse_register(line.operands[0], line.lineno);
        int rt = parse_register(line.operands[1], line.lineno);
        return static_cast<std::uint16_t>(0xF808 | (ra << 6) | rt);
    }

    throw AsmError("line " + std::to_string(line.lineno) + ": unsupported mnemonic '" + mnem + "'");
}

std::vector<ParsedLine> parse_source(const std::string& path) {
    std::ifstream in(path);
    if (!in) {
        throw AsmError("unable to open source file '" + path + "'");
    }

    std::vector<ParsedLine> lines;
    std::string line;
    int lineno = 1;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        lines.push_back(parse_line(lineno, line));
        ++lineno;
    }
    return lines;
}

std::unordered_map<std::string, int> first_pass(const std::vector<ParsedLine>& lines) {
    std::unordered_map<std::string, int> labels;
    int pc = 0;
    for (const ParsedLine& line : lines) {
        if (!line.label.empty()) {
            if (labels.find(line.label) != labels.end()) {
                throw AsmError("line " + std::to_string(line.lineno) + ": duplicate label '" + line.label + "'");
            }
            labels[line.label] = pc;
        }
        if (!line.mnemonic.empty()) {
            pc += 2;
        }
    }
    return labels;
}

struct OutputLine {
    ParsedLine line;
    std::uint16_t word;
};

std::vector<OutputLine> assemble(const std::vector<ParsedLine>& lines,
                                 const std::unordered_map<std::string, int>& labels) {
    std::vector<OutputLine> items;
    for (const ParsedLine& line : lines) {
        if (line.mnemonic.empty()) {
            continue;
        }
        items.push_back(OutputLine{line, encode_instruction(line, labels)});
    }
    return items;
}

std::string format_output(const std::vector<OutputLine>& items) {
    std::ostringstream out;
    out << "@0\n";
    for (const OutputLine& item : items) {
        std::uint8_t hi = static_cast<std::uint8_t>((item.word >> 8) & 0xFF);
        std::uint8_t lo = static_cast<std::uint8_t>(item.word & 0xFF);
        out << "// " << trim(item.line.original) << "\n";
        out << std::bitset<8>(hi) << " " << std::bitset<8>(lo) << "\n";
    }
    return out.str();
}

}  // namespace

int main(int argc, char* argv[]) {
    if (argc < 2 || argc > 3) {
        std::cerr << "usage: " << argv[0] << " source.s [output.bin]\n";
        return 1;
    }

    const std::string source_path = argv[1];
    std::string output_path;
    if (argc == 3) {
        output_path = argv[2];
    } else {
        std::size_t dot = source_path.find_last_of('.');
        output_path = (dot == std::string::npos) ? source_path + ".bin" : source_path.substr(0, dot) + ".bin";
    }

    try {
        std::vector<ParsedLine> lines = parse_source(source_path);
        std::unordered_map<std::string, int> labels = first_pass(lines);
        std::vector<OutputLine> items = assemble(lines, labels);

        std::filesystem::path out_path(output_path);
        if (out_path.has_parent_path()) {
            std::filesystem::create_directories(out_path.parent_path());
        }

        std::ofstream out(output_path);
        if (!out) {
            throw AsmError("unable to open output file '" + output_path + "'");
        }
        out << format_output(items);
    } catch (const AsmError& exc) {
        std::cerr << "assembler error: " << exc.what() << "\n";
        return 1;
    }

    return 0;
}
