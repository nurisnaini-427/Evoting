// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EVotingLingkungan
 * @dev Sistem e-voting untuk keputusan warga lingkungan
 *      1 alamat wallet = 1 suara per topik voting
 */
contract EVotingLingkungan {

    // ─── Structs ───────────────────────────────────────────────

    struct Pilihan {
        string nama;
        uint256 jumlahSuara;
    }

    struct Voting {
        uint256 id;
        string judul;
        string deskripsi;
        Pilihan[] pilihan;
        bool aktif;
        uint256 totalSuara;
        uint256 waktuMulai;
        uint256 waktuSelesai; // 0 = tidak ada batas waktu
        mapping(address => bool) sudahVoting;
    }

    // ─── State Variables ───────────────────────────────────────

    address public owner;
    uint256 public jumlahVoting;

    mapping(uint256 => Voting) private daftarVoting;

    // ─── Events ────────────────────────────────────────────────

    event VotingDibuat(
        uint256 indexed votingId,
        string judul,
        uint256 waktuMulai
    );

    event SuaraDiberikan(
        uint256 indexed votingId,
        address indexed pemilih,
        uint256 indexed pilihanId,
        string namaPilihan
    );

    event VotingDitutup(
        uint256 indexed votingId,
        string judul,
        uint256 totalSuara
    );

    event PemenangTerpilih(
        uint256 indexed votingId,
        uint256 pilihanId,
        string namaPemenang,
        uint256 jumlahSuara
    );

    // ─── Modifiers ─────────────────────────────────────────────

    modifier hanyaOwner() {
        require(msg.sender == owner, "Hanya owner yang bisa melakukan ini");
        _;
    }

    modifier votingValid(uint256 _votingId) {
        require(_votingId > 0 && _votingId <= jumlahVoting, "ID voting tidak valid");
        _;
    }

    modifier votingMasihAktif(uint256 _votingId) {
        Voting storage v = daftarVoting[_votingId];
        require(v.aktif, "Voting sudah ditutup");
        if (v.waktuSelesai > 0) {
            require(block.timestamp <= v.waktuSelesai, "Waktu voting sudah habis");
        }
        _;
    }

    // ─── Constructor ───────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─── Owner Functions ───────────────────────────────────────

    /**
     * @dev Buat topik voting baru
     * @param _judul Judul voting (misal: "Jadwal Kerja Bakti Bulan Ini")
     * @param _deskripsi Penjelasan singkat topik voting
     * @param _pilihan Array nama-nama pilihan (min 2)
     * @param _durasiJam Durasi voting dalam jam (0 = tidak terbatas)
     */
    function buatVoting(
        string memory _judul,
        string memory _deskripsi,
        string[] memory _pilihan,
        uint256 _durasiJam
    ) external hanyaOwner {
        require(bytes(_judul).length > 0, "Judul tidak boleh kosong");
        require(_pilihan.length >= 2, "Minimal 2 pilihan diperlukan");
        require(_pilihan.length <= 10, "Maksimal 10 pilihan");

        jumlahVoting++;
        Voting storage v = daftarVoting[jumlahVoting];

        v.id = jumlahVoting;
        v.judul = _judul;
        v.deskripsi = _deskripsi;
        v.aktif = true;
        v.totalSuara = 0;
        v.waktuMulai = block.timestamp;
        v.waktuSelesai = _durasiJam > 0
            ? block.timestamp + (_durasiJam * 1 hours)
            : 0;

        for (uint256 i = 0; i < _pilihan.length; i++) {
            require(bytes(_pilihan[i]).length > 0, "Nama pilihan tidak boleh kosong");
            v.pilihan.push(Pilihan({
                nama: _pilihan[i],
                jumlahSuara: 0
            }));
        }

        emit VotingDibuat(jumlahVoting, _judul, block.timestamp);
    }

    /**
     * @dev Tutup voting secara manual oleh owner
     * @param _votingId ID voting yang ingin ditutup
     */
    function tutupVoting(uint256 _votingId)
        external
        hanyaOwner
        votingValid(_votingId)
    {
        Voting storage v = daftarVoting[_votingId];
        require(v.aktif, "Voting sudah ditutup sebelumnya");

        v.aktif = false;
        emit VotingDitutup(_votingId, v.judul, v.totalSuara);

        // Umumkan pemenang jika ada suara masuk
        if (v.totalSuara > 0) {
            (uint256 pemenangId, uint256 suaraTerbanyak) = _cariPemenang(_votingId);
            emit PemenangTerpilih(
                _votingId,
                pemenangId,
                v.pilihan[pemenangId].nama,
                suaraTerbanyak
            );
        }
    }

    // ─── Public Functions ──────────────────────────────────────

    /**
     * @dev Warga memberikan suara
     * @param _votingId ID voting yang diikuti
     * @param _pilihanId Index pilihan (mulai dari 0)
     */
    function berikanSuara(uint256 _votingId, uint256 _pilihanId)
        external
        votingValid(_votingId)
        votingMasihAktif(_votingId)
    {
        Voting storage v = daftarVoting[_votingId];

        require(
            !v.sudahVoting[msg.sender],
            "Anda sudah memberikan suara pada voting ini"
        );
        require(
            _pilihanId < v.pilihan.length,
            "ID pilihan tidak valid"
        );

        v.sudahVoting[msg.sender] = true;
        v.pilihan[_pilihanId].jumlahSuara++;
        v.totalSuara++;

        emit SuaraDiberikan(
            _votingId,
            msg.sender,
            _pilihanId,
            v.pilihan[_pilihanId].nama
        );
    }

    // ─── View Functions ────────────────────────────────────────

    /**
     * @dev Ambil info dasar sebuah voting
     */
    function infoVoting(uint256 _votingId)
        external
        view
        votingValid(_votingId)
        returns (
            string memory judul,
            string memory deskripsi,
            bool aktif,
            uint256 totalSuara,
            uint256 waktuMulai,
            uint256 waktuSelesai,
            uint256 jumlahPilihan
        )
    {
        Voting storage v = daftarVoting[_votingId];
        return (
            v.judul,
            v.deskripsi,
            v.aktif,
            v.totalSuara,
            v.waktuMulai,
            v.waktuSelesai,
            v.pilihan.length
        );
    }

    /**
     * @dev Lihat semua pilihan dan jumlah suaranya
     */
    function lihatHasil(uint256 _votingId)
        external
        view
        votingValid(_votingId)
        returns (
            string[] memory namaPilihan,
            uint256[] memory jumlahSuaraPerPilihan
        )
    {
        Voting storage v = daftarVoting[_votingId];
        uint256 n = v.pilihan.length;

        namaPilihan = new string[](n);
        jumlahSuaraPerPilihan = new uint256[](n);

        for (uint256 i = 0; i < n; i++) {
            namaPilihan[i] = v.pilihan[i].nama;
            jumlahSuaraPerPilihan[i] = v.pilihan[i].jumlahSuara;
        }
    }

    /**
     * @dev Cek apakah sebuah alamat sudah voting
     */
    function sudahVoting(uint256 _votingId, address _alamat)
        external
        view
        votingValid(_votingId)
        returns (bool)
    {
        return daftarVoting[_votingId].sudahVoting[_alamat];
    }

    /**
     * @dev Ambil pemenang voting (bisa dipanggil saat voting masih aktif)
     */
    function pemenangSementara(uint256 _votingId)
        external
        view
        votingValid(_votingId)
        returns (
            uint256 pilihanId,
            string memory namaPemenang,
            uint256 jumlahSuara,
            bool adaSeri
        )
    {
        Voting storage v = daftarVoting[_votingId];
        require(v.totalSuara > 0, "Belum ada suara yang masuk");

        (uint256 id, uint256 suara) = _cariPemenang(_votingId);
        bool seri = _cekSeri(_votingId, suara);

        return (id, v.pilihan[id].nama, suara, seri);
    }

    /**
     * @dev Lihat daftar semua voting (id, judul, status)
     */
    function daftarSemuaVoting()
        external
        view
        returns (
            uint256[] memory ids,
            string[] memory juduls,
            bool[] memory statusAktif,
            uint256[] memory totalSuaras
        )
    {
        ids = new uint256[](jumlahVoting);
        juduls = new string[](jumlahVoting);
        statusAktif = new bool[](jumlahVoting);
        totalSuaras = new uint256[](jumlahVoting);

        for (uint256 i = 1; i <= jumlahVoting; i++) {
            Voting storage v = daftarVoting[i];
            ids[i - 1] = v.id;
            juduls[i - 1] = v.judul;
            statusAktif[i - 1] = v.aktif;
            totalSuaras[i - 1] = v.totalSuara;
        }
    }

    // ─── Internal Functions ────────────────────────────────────

    function _cariPemenang(uint256 _votingId)
        internal
        view
        returns (uint256 pemenangId, uint256 suaraTerbanyak)
    {
        Voting storage v = daftarVoting[_votingId];
        suaraTerbanyak = 0;
        pemenangId = 0;

        for (uint256 i = 0; i < v.pilihan.length; i++) {
            if (v.pilihan[i].jumlahSuara > suaraTerbanyak) {
                suaraTerbanyak = v.pilihan[i].jumlahSuara;
                pemenangId = i;
            }
        }
    }

    function _cekSeri(uint256 _votingId, uint256 _suaraTerbanyak)
        internal
        view
        returns (bool)
    {
        Voting storage v = daftarVoting[_votingId];
        uint256 count = 0;
        for (uint256 i = 0; i < v.pilihan.length; i++) {
            if (v.pilihan[i].jumlahSuara == _suaraTerbanyak) {
                count++;
            }
        }
        return count > 1;
    }
}