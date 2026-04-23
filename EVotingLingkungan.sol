// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EVotingLingkungan {

    address public admin;
    string public judulVoting;
    bool public votingAktif;

    struct Opsi {
        string nama;
        uint jumlahSuara;
    }

    Opsi[] private daftarOpsi;

    mapping(address => bool) public sudahMemilih;

    // =========================
    // CONSTRUCTOR
    // =========================
    constructor(string memory _judul) {
        admin = msg.sender;
        judulVoting = _judul;
        votingAktif = true;
    }

    // =========================
    // MODIFIER
    // =========================
    modifier hanyaAdmin() {
        require(msg.sender == admin, "Hanya admin!");
        _;
    }

    modifier saatAktif() {
        require(votingAktif == true, "Voting sudah ditutup!");
        _;
    }

    // =========================
    // TAMBAH OPSI
    // =========================
    function tambahOpsi(string memory _namaOpsi) public hanyaAdmin {
        daftarOpsi.push(Opsi(_namaOpsi, 0));
    }

    // =========================
    // VOTING
    // =========================
    function vote(uint _indexOpsi) public saatAktif {
        require(!sudahMemilih[msg.sender], "Anda sudah voting!");
        require(_indexOpsi < daftarOpsi.length, "Opsi tidak valid!");

        sudahMemilih[msg.sender] = true;
        daftarOpsi[_indexOpsi].jumlahSuara++;
    }

    // =========================
    // LIHAT JUMLAH OPSI
    // =========================
    function getJumlahOpsi() public view returns (uint) {
        return daftarOpsi.length;
    }

    // =========================
    // LIHAT SATU OPSI
    // =========================
    function getOpsi(uint index) public view returns (string memory, uint) {
        return (daftarOpsi[index].nama, daftarOpsi[index].jumlahSuara);
    }

    // =========================
    // LIHAT SEMUA OPSI
    // =========================
    function getSemuaOpsi() public view returns (Opsi[] memory) {
        return daftarOpsi;
    }

    // =========================
    // TUTUP VOTING
    // =========================
    function tutupVoting() public hanyaAdmin {
        votingAktif = false;
    }
}